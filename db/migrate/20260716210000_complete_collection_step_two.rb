class CompleteCollectionStepTwo < ActiveRecord::Migration[8.1]
  def change
    add_column :design_collections, :archived_at, :datetime
    add_column :plans, :design_collections_enabled, :boolean, null: false, default: true

    reversible do |direction|
      direction.up do
        execute <<~SQL.squish
          UPDATE design_collections
          SET archived_at = updated_at
          WHERE active = FALSE AND archived_at IS NULL
        SQL
        execute <<~SQL.squish
          UPDATE plans
          SET design_collections_enabled = TRUE
          WHERE code IN ('starter', 'professional')
        SQL
      end
    end
  end
end
