class CreateMeasurements < ActiveRecord::Migration[8.1]
  def change
    create_table :measurements do |t|
      t.references :measurement_profile, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :copied_from, null: true, foreign_key: { to_table: :measurements }
      t.integer :version, null: false
      t.date :measured_on, null: false
      t.jsonb :values, null: false, default: {}
      t.text :notes

      t.timestamps
    end


    add_index :measurements, [ :measurement_profile_id, :version ], unique: true
    add_index :measurements, [ :measurement_profile_id, :measured_on ]
    add_check_constraint :measurements, "version > 0", name: "measurements_version_positive"
    add_check_constraint :measurements, "jsonb_typeof(values) = 'object'", name: "measurements_values_object"
  end
end
