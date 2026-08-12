class CreateSaasFoundation < ActiveRecord::Migration[8.1]
  ROLE_VALUES = {
    owner: 0, manager: 1, receptionist: 2, cashier: 3, tailor: 4,
    cutting_staff: 5, embroidery_staff: 6, ironing_staff: 7
  }.freeze

  def up
    create_table :shops do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :country, null: false, default: "India"
      t.boolean :active, null: false, default: true
      t.datetime :onboarding_completed_at
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :shops, :slug, unique: true
    add_check_constraint :shops, "length(trim(name)) > 0 AND length(trim(slug)) > 0", name: "shops_identity_present"

    add_reference :branches, :shop, foreign_key: true
    backfill_default_shop
    change_column_null :branches, :shop_id, false
    remove_index :branches, :code
    add_index :branches, [ :shop_id, :code ], unique: true

    create_table :plans do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.decimal :monthly_price, precision: 12, scale: 2, null: false
      t.decimal :annual_price, precision: 12, scale: 2, null: false
      t.string :currency, null: false, default: "INR"
      t.boolean :active, null: false, default: true
      t.integer :trial_days, null: false, default: 14
      t.integer :customer_limit
      t.integer :staff_limit
      t.integer :monthly_order_limit
      t.boolean :inventory_enabled, null: false, default: false
      t.boolean :advanced_reports_enabled, null: false, default: false
      t.boolean :custom_branding_enabled, null: false, default: false
      t.boolean :multiple_branches_enabled, null: false, default: false
      t.timestamps
    end
    add_index :plans, :code, unique: true
    add_check_constraint :plans, "monthly_price >= 0 AND annual_price >= 0 AND trial_days >= 0", name: "plans_pricing_nonnegative"

    create_table :memberships do |t|
      t.references :shop, null: false, foreign_key: true, index: false
      t.references :user, null: false, foreign_key: true
      t.references :branch, null: false, foreign_key: true
      t.integer :role, null: false, default: ROLE_VALUES.fetch(:receptionist)
      t.boolean :active, null: false, default: true
      t.string :employee_code
      t.string :job_title
      t.date :joined_on
      t.integer :pay_basis, null: false, default: 0
      t.decimal :pay_rate, precision: 12, scale: 2, null: false, default: 0
      t.datetime :accepted_at
      t.timestamps
    end
    add_index :memberships, [ :user_id, :shop_id ], unique: true
    add_index :memberships, [ :shop_id, :role, :active ]
    add_index :memberships, [ :shop_id, :employee_code ], unique: true, where: "employee_code IS NOT NULL"
    add_check_constraint :memberships, "role >= 0 AND role <= 7", name: "memberships_role_range"
    add_check_constraint :memberships, "pay_basis >= 0 AND pay_basis <= 3 AND pay_rate >= 0", name: "memberships_pay_valid"

    create_table :subscriptions do |t|
      t.references :shop, null: false, foreign_key: true, index: false
      t.references :plan, null: false, foreign_key: true
      t.integer :status, null: false, default: 0
      t.integer :billing_interval, null: false, default: 0
      t.datetime :trial_started_at
      t.datetime :trial_ends_at
      t.datetime :current_period_started_at
      t.datetime :current_period_ends_at
      t.datetime :grace_period_ends_at
      t.datetime :cancelled_at
      t.string :provider
      t.string :provider_customer_id
      t.string :provider_subscription_id
      t.timestamps
    end
    add_index :subscriptions, :shop_id, unique: true
    add_index :subscriptions, [ :status, :trial_ends_at ]
    add_index :subscriptions, [ :provider, :provider_subscription_id ], unique: true, where: "provider_subscription_id IS NOT NULL"
    add_check_constraint :subscriptions, "status >= 0 AND status <= 6", name: "subscriptions_status_range"
    add_check_constraint :subscriptions, "billing_interval >= 0 AND billing_interval <= 1", name: "subscriptions_interval_range"

    create_table :staff_invitations do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :branch, null: false, foreign_key: true
      t.string :email, null: false
      t.integer :role, null: false
      t.string :token_digest, null: false
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :staff_invitations, :token_digest, unique: true
    add_index :staff_invitations, [ :shop_id, :email ], unique: true,
      where: "accepted_at IS NULL AND revoked_at IS NULL", name: "index_active_staff_invitations_on_shop_email"
    add_check_constraint :staff_invitations, "role >= 1 AND role <= 7", name: "staff_invitations_role_range"

    create_table :business_audit_events do |t|
      t.references :shop, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.string :auditable_type
      t.bigint :auditable_id
      t.jsonb :metadata, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.string :request_id
      t.string :ip_address
      t.string :user_agent
      t.text :reason
      t.timestamps
    end
    add_index :business_audit_events, [ :auditable_type, :auditable_id ], name: "index_business_audits_on_auditable"
    add_index :business_audit_events, [ :shop_id, :occurred_at ]
    add_index :business_audit_events, :request_id
    add_index :business_audit_events, [ :action, :occurred_at ]

    add_column :users, :terms_accepted_at, :datetime

    seed_plans
    backfill_memberships_and_subscription
  end

  def down
    remove_column :users, :terms_accepted_at
    drop_table :business_audit_events
    drop_table :staff_invitations
    drop_table :subscriptions
    drop_table :memberships
    drop_table :plans
    remove_index :branches, [ :shop_id, :code ]
    add_index :branches, :code, unique: true
    remove_reference :branches, :shop, foreign_key: true
    drop_table :shops
  end

  private

  def backfill_default_shop
    name = select_value("SELECT shop_name FROM shop_settings ORDER BY id LIMIT 1").presence ||
      select_value("SELECT name FROM branches ORDER BY id LIMIT 1").presence || "Puitei Chhakchhuak"
    quoted_name = connection.quote(name)
    execute <<~SQL.squish
      INSERT INTO shops (name, slug, country, active, created_at, updated_at)
      VALUES (#{quoted_name}, 'default-shop', 'India', TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
    execute "UPDATE branches SET shop_id = (SELECT id FROM shops WHERE slug = 'default-shop')"
  end

  def seed_plans
    execute <<~SQL.squish
      INSERT INTO plans
        (name, code, monthly_price, annual_price, currency, active, trial_days, customer_limit, staff_limit,
         monthly_order_limit, inventory_enabled, advanced_reports_enabled, custom_branding_enabled,
         multiple_branches_enabled, created_at, updated_at)
      VALUES
        ('Starter', 'starter', 499, 4990, 'INR', TRUE, 14, 300, 2, 100, FALSE, FALSE, FALSE, FALSE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('Professional', 'professional', 999, 9990, 'INR', TRUE, 14, NULL, 8, NULL, TRUE, TRUE, TRUE, FALSE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
  end

  def backfill_memberships_and_subscription
    execute <<~SQL.squish
      INSERT INTO memberships
        (shop_id, user_id, branch_id, role, active, employee_code, job_title, joined_on, pay_basis, pay_rate,
         accepted_at, created_at, updated_at)
      SELECT branches.shop_id, users.id, users.branch_id, users.role, users.active, users.employee_code,
             users.job_title, users.joined_on, users.pay_basis, users.pay_rate, users.created_at,
             CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM users INNER JOIN branches ON branches.id = users.branch_id
    SQL
    execute <<~SQL.squish
      UPDATE shops
      SET created_by_id = memberships.user_id
      FROM memberships
      WHERE memberships.shop_id = shops.id AND memberships.role = #{ROLE_VALUES.fetch(:owner)}
    SQL
    execute <<~SQL.squish
      INSERT INTO subscriptions
        (shop_id, plan_id, status, billing_interval, trial_started_at, trial_ends_at, created_at, updated_at)
      SELECT shops.id, plans.id, 0, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + INTERVAL '14 days', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM shops CROSS JOIN plans WHERE plans.code = 'professional'
    SQL
  end
end
