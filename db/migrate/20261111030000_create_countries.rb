# frozen_string_literal: true

class CreateCountries < ActiveRecord::Migration[8.1]
  def change
    create_table :countries do |t|
      t.references :continent, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description, null: false
      t.jsonb :themes, null: false, default: []

      t.timestamps
    end

    add_index :countries, "continent_id, LOWER(name)", unique: true, name: "index_countries_on_continent_id_and_lower_name"
  end
end
