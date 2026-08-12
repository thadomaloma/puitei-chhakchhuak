class AddPhaseOneFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :branch, null: false, foreign_key: true, index: true
    add_column :users, :name, :string, null: false
    add_column :users, :role, :integer, null: false, default: 2
    add_column :users, :active, :boolean, null: false, default: true

    add_index :users, [ :branch_id, :role ]
    add_check_constraint :users, "length(trim(name)) > 0", name: "users_name_present"
    add_check_constraint :users, "role BETWEEN 0 AND 7", name: "users_role_range"
  end
end
