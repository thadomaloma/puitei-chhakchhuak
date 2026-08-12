class AddCoverDesignToDesignCollections < ActiveRecord::Migration[8.1]
  def change
    add_reference :design_collections, :cover_design, null: true,
      foreign_key: { to_table: :designs }
  end
end
