class CompleteDesignStudioPhaseB < ActiveRecord::Migration[8.1]
  def change
    add_column :plans, :design_selection_limit_per_customer, :integer
    add_column :plans, :favourites_enabled, :boolean, null: false, default: true
    add_column :plans, :customer_design_selection_enabled, :boolean, null: false, default: true
    add_column :plans, :advanced_collection_filters_enabled, :boolean, null: false, default: false
    add_check_constraint :plans,
      "design_selection_limit_per_customer IS NULL OR design_selection_limit_per_customer > 0",
      name: "plans_design_selection_limit_positive"

    add_column :design_selections, :approved_at, :datetime
    change_column_default :design_selections, :status, from: 0, to: 1
    add_index :design_selections, [ :shop_id, :customer_id, :archived_at, :status ],
      name: "index_design_selections_on_customer_gallery"

    reversible do |direction|
      direction.up do
        execute <<~SQL.squish
          UPDATE design_selections
          SET approved_at = selected_at
          WHERE status IN (2, 4) AND approved_at IS NULL
        SQL
        execute <<~SQL.squish
          UPDATE plans
          SET design_selection_limit_per_customer = 20,
              favourites_enabled = TRUE,
              customer_design_selection_enabled = TRUE,
              advanced_collection_filters_enabled = FALSE
          WHERE code = 'starter'
        SQL
        execute <<~SQL.squish
          UPDATE plans
          SET design_selection_limit_per_customer = 100,
              favourites_enabled = TRUE,
              customer_design_selection_enabled = TRUE,
              advanced_collection_filters_enabled = TRUE
          WHERE code = 'professional'
        SQL
      end
    end
  end
end
