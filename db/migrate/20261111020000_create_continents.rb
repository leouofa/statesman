# frozen_string_literal: true

class CreateContinents < ActiveRecord::Migration[8.1]
  def change
    create_table :continents do |t|
      t.string :name, null: false
      t.text :description, null: false

      t.timestamps
    end

    add_index :continents, "LOWER(name)", unique: true, name: "index_continents_on_lower_name"
  end
end
