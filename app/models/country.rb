# frozen_string_literal: true

class Country < ApplicationRecord
  include Embeddable

  belongs_to :continent
  has_many :cities, dependent: :destroy

  normalizes :name, with: ->(value) { value.to_s.squish }
  normalizes :description, with: ->(value) { value.to_s.strip }
  normalizes :themes, with: ->(value) { normalize_themes(value) }

  validates :name, presence: true, uniqueness: { scope: :continent_id, case_sensitive: false }
  validates :description, presence: true
  validate :themes_must_be_string_array

  scope :ordered, -> { order(:name) }

  def embedding_input
    lines = [
      "Country: #{name} (#{continent.name})",
      "Description: #{description}"
    ]
    lines << "Themes: #{themes.join(', ')}" if themes.any?
    lines.join("\n")
  end

  # Returns [continent, Array<Country>] pairs ordered by continent name then country name.
  def self.grouped_by_continent
    includes(:continent)
      .joins(:continent)
      .order("continents.name ASC, countries.name ASC")
      .group_by(&:continent)
      .to_a
  end

  # Upserts an enumerable of { name:, description:, themes: } entries scoped to
  # the given continent, matching case-insensitively on normalized name.
  def self.upsert_batch!(continent, entries)
    raise ArgumentError, "continent must be present" if continent.nil?

    transaction do
      Array(entries).filter_map do |entry|
        attrs = entry.respond_to?(:to_h) ? entry.to_h.symbolize_keys : {}
        name = attrs[:name].to_s.squish
        description = attrs[:description].to_s.strip
        next if name.blank? || description.blank?

        themes = normalize_themes(attrs[:themes])
        upsert_one!(continent: continent, name: name, description: description, themes: themes)
      end
    end
  end

  def self.normalize_themes(value)
    items =
      case value
      when Array
        value
      when String
        value.split(",")
      else
        []
      end

    items.filter_map { |item| item.to_s.squish.presence }.uniq(&:downcase)
  end

  def self.upsert_one!(continent:, name:, description:, themes:)
    scope = continent.countries
    record = scope.where("LOWER(name) = ?", name.downcase).first_or_initialize
    record.assign_attributes(name: name, description: description, themes: themes)
    record.save!
    record
  rescue ActiveRecord::RecordNotUnique
    record = scope.where("LOWER(name) = ?", name.downcase).first!
    record.update!(name: name, description: description, themes: themes)
    record
  end
  private_class_method :upsert_one!

  private

  def themes_must_be_string_array
    unless themes.is_a?(Array) && themes.all? { |item| item.is_a?(String) && item.present? }
      errors.add(:themes, "must be a list of non-empty strings")
    end
  end
end
