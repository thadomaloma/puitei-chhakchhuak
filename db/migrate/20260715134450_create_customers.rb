class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.references :branch, null: false, foreign_key: true
      t.string :customer_code, null: false
      t.string :full_name, null: false
      t.string :phone_number, null: false
      t.string :whatsapp_number
      t.string :email
      t.integer :gender, null: false, default: 0
      t.date :date_of_birth
      t.text :address
      t.string :city
      t.text :notes
      t.string :preferred_language, null: false, default: "en"
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :customers, :customer_code, unique: true
    add_index :customers, [ :branch_id, :phone_number ], unique: true
    add_index :customers, [ :branch_id, :active, :full_name ]
    add_index :customers, "lower(full_name)", name: "index_customers_on_lower_full_name"
    add_check_constraint :customers, "length(trim(full_name)) > 0", name: "customers_name_present"
    add_check_constraint :customers, "phone_number ~ '^[0-9]{7,15}$'", name: "customers_phone_format"
    add_check_constraint :customers, "gender BETWEEN 0 AND 3", name: "customers_gender_range"
    add_check_constraint :customers, "preferred_language IN ('en', 'lus', 'hi')", name: "customers_language"
  end
end
