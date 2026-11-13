# frozen_string_literal: true

class CreateCities < ActiveRecord::Migration[8.1]
  def change
    create_table :cities do |t|
      t.references :country, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description, null: false
      t.jsonb :themes, null: false, default: []

      t.timestamps
    end

    add_index :cities, "country_id, LOWER(name)", unique: true, name: "index_cities_on_country_id_and_lower_name"
  end
end
