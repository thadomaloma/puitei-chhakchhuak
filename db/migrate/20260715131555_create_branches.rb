class CreateBranches < ActiveRecord::Migration[8.1]
  def change
    create_table :branches do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.string :phone
      t.string :email
      t.text :address
      t.boolean :active, null: false, default: true
      t.string :locale, null: false, default: "en"
      t.string :time_zone, null: false, default: "Asia/Kolkata"

      t.timestamps
    end

    add_index :branches, :code, unique: true
    add_check_constraint :branches, "length(trim(name)) > 0", name: "branches_name_present"
    add_check_constraint :branches, "code ~ '^[A-Z0-9_-]+$'", name: "branches_code_format"
  end
end
