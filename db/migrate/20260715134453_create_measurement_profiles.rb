class CreateMeasurementProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :measurement_profiles do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :measurement_template, null: false, foreign_key: true
      t.string :name, null: false
      t.string :unit, null: false, default: "inches"
      t.text :fitting_notes
      t.text :posture_notes
      t.text :preferences
      t.boolean :active, null: false, default: true

      t.timestamps
    end


    add_index :measurement_profiles, [ :customer_id, :active ]
    add_check_constraint :measurement_profiles, "unit IN ('inches', 'centimetres')", name: "measurement_profiles_unit"
    add_check_constraint :measurement_profiles, "length(trim(name)) > 0", name: "measurement_profiles_name_present"
  end
end
