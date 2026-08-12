class MoveEmployeeCodeUniquenessToMemberships < ActiveRecord::Migration[8.1]
  def change
    remove_index :users, :employee_code, unique: true
    add_index :users, :employee_code
  end
end
