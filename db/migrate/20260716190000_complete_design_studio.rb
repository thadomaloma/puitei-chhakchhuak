class CompleteDesignStudio < ActiveRecord::Migration[8.1]
  def change
    add_column :plans, :design_image_limit, :integer
    add_column :plans, :collection_limit, :integer
    add_column :plans, :active_share_limit, :integer
    add_column :plans, :customer_sharing_enabled, :boolean, null: false, default: false
    add_column :plans, :advanced_design_filters_enabled, :boolean, null: false, default: false
    add_column :plans, :ai_design_enabled, :boolean, null: false, default: false
    add_column :plans, :monthly_ai_credit_limit, :integer, null: false, default: 0

    add_check_constraint :plans,
      "design_image_limit IS NULL OR design_image_limit > 0", name: "plans_design_image_limit_positive"
    add_check_constraint :plans,
      "collection_limit IS NULL OR collection_limit > 0", name: "plans_collection_limit_positive"
    add_check_constraint :plans,
      "active_share_limit IS NULL OR active_share_limit > 0", name: "plans_active_share_limit_positive"
    add_check_constraint :plans,
      "monthly_ai_credit_limit >= 0", name: "plans_ai_credit_limit_nonnegative"

    add_column :designs, :design_selections_count, :integer, null: false, default: 0
    add_column :designs, :design_share_items_count, :integer, null: false, default: 0
    add_check_constraint :designs,
      "design_selections_count >= 0 AND design_share_items_count >= 0", name: "designs_usage_counts_nonnegative"

    create_table :design_favourites do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :design, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :design_favourites, [ :shop_id, :user_id, :design_id ], unique: true,
      name: "index_design_favourites_on_shop_user_design"

    create_table :design_selections do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :customer, null: false, foreign_key: true
      t.references :design, null: false, foreign_key: true
      t.references :selected_by, null: false, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.text :customer_note
      t.text :internal_note
      t.datetime :selected_at, null: false
      t.datetime :archived_at
      t.timestamps
    end
    add_index :design_selections, [ :shop_id, :customer_id, :selected_at ],
      name: "index_design_selections_on_shop_customer_selected"
    add_index :design_selections, [ :shop_id, :design_id, :status ],
      name: "index_design_selections_on_shop_design_status"
    add_index :design_selections, [ :shop_id, :customer_id, :design_id ], unique: true,
      where: "archived_at IS NULL", name: "index_active_design_selections_unique"
    add_check_constraint :design_selections, "status >= 0 AND status <= 4",
      name: "design_selections_status_range"

    create_table :design_shares do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :customer, null: false, foreign_key: true
      t.references :design_collection, foreign_key: true
      t.string :token_digest, null: false
      t.string :token_hint, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.datetime :viewed_at
      t.boolean :allow_feedback, null: false, default: true
      t.string :title
      t.text :message
      t.timestamps
    end
    add_index :design_shares, :token_digest, unique: true
    add_index :design_shares, [ :shop_id, :revoked_at, :expires_at ],
      name: "index_design_shares_on_shop_activity"

    create_table :design_share_items do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :design_share, null: false, foreign_key: true
      t.references :design, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.integer :customer_reaction, null: false, default: 0
      t.text :customer_comment
      t.datetime :responded_at
      t.timestamps
    end
    add_index :design_share_items, [ :design_share_id, :design_id ], unique: true
    add_index :design_share_items, [ :design_share_id, :position, :id ],
      name: "index_design_share_items_on_share_position"
    add_check_constraint :design_share_items, "position >= 0",
      name: "design_share_items_position_nonnegative"
    add_check_constraint :design_share_items, "customer_reaction >= 0 AND customer_reaction <= 3",
      name: "design_share_items_reaction_range"

    create_table :ai_design_requests do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.references :source_design, foreign_key: { to_table: :designs }
      t.references :result_design, foreign_key: { to_table: :designs }
      t.integer :request_type, null: false
      t.text :prompt, null: false
      t.text :negative_prompt
      t.integer :status, null: false, default: 0
      t.string :provider, null: false, default: "disabled"
      t.string :provider_request_id
      t.integer :credit_cost, null: false, default: 1
      t.string :error_code
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :ai_design_requests, [ :shop_id, :created_at ],
      name: "index_ai_design_requests_on_shop_created"
    add_index :ai_design_requests, [ :provider, :provider_request_id ], unique: true,
      where: "provider_request_id IS NOT NULL", name: "index_ai_design_requests_on_provider_request"
    add_check_constraint :ai_design_requests, "request_type >= 0 AND request_type <= 5",
      name: "ai_design_requests_type_range"
    add_check_constraint :ai_design_requests, "status >= 0 AND status <= 5",
      name: "ai_design_requests_status_range"
    add_check_constraint :ai_design_requests, "credit_cost > 0",
      name: "ai_design_requests_credit_cost_positive"

    reversible do |direction|
      direction.up do
        execute <<~SQL.squish
          UPDATE plans SET
            design_image_limit = 100,
            collection_limit = 10,
            active_share_limit = 2,
            customer_sharing_enabled = TRUE
          WHERE code = 'starter'
        SQL
        execute <<~SQL.squish
          UPDATE plans SET
            design_image_limit = 1000,
            collection_limit = 100,
            active_share_limit = 50,
            customer_sharing_enabled = TRUE,
            advanced_design_filters_enabled = TRUE,
            ai_design_enabled = TRUE,
            monthly_ai_credit_limit = 50
          WHERE code = 'professional'
        SQL
      end
    end
  end
end
