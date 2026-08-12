class DropSaasPlanAndSubscriptionTables < ActiveRecord::Migration[8.1]
  def up
    drop_table :subscriptions if table_exists?(:subscriptions)
    drop_table :plans if table_exists?(:plans)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "SaaS plan and subscription tables must not be restored"
  end
end
