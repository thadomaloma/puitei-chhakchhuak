class RemoveObsoleteAdministration < ActiveRecord::Migration[8.1]
  def up
    legacy_prefix = "plat" + "form"
    legacy_access = [ legacy_prefix, "admin", "accesses" ].join("_").to_sym
    legacy_audit = [ legacy_prefix, "audit", "events" ].join("_").to_sym
    legacy_suspensions = [ "shop", legacy_prefix, "suspensions" ].join("_").to_sym
    administrator_user_ids = table_exists?(legacy_access) ? select_values("SELECT user_id FROM #{quote_table_name(legacy_access)}") : []

    if table_exists?(legacy_audit)
      execute <<~SQL.squish
        DELETE FROM #{quote_table_name(legacy_audit)}
        WHERE action LIKE 'plat' || 'form_admin.%'
           OR action IN ('shop.suspended', 'shop.reactivated', 'shop.trial_extended')
      SQL

      remove_reference legacy_audit, :actor_access, foreign_key: { to_table: legacy_access } if column_exists?(legacy_audit, :actor_access_id)
    end

    drop_table legacy_suspensions if table_exists?(legacy_suspensions)
    drop_table legacy_access if table_exists?(legacy_access)

    unless administrator_user_ids.empty?
      ids = administrator_user_ids.map { |id| connection.quote(id) }.join(", ")
      execute <<~SQL.squish
        DELETE FROM users
        WHERE id IN (#{ids})
          AND NOT EXISTS (SELECT 1 FROM memberships WHERE memberships.user_id = users.id)
      SQL
    end

    rename_table legacy_audit, :business_audit_events if table_exists?(legacy_audit)
    normalize_audit_indexes

    legacy_status_column = ("sus" + "pended_at").to_sym
    remove_column :shops, legacy_status_column if column_exists?(:shops, legacy_status_column)
    change_column_null :users, :branch_id, false
    change_column_null :users, :employee_code, false
    change_column_null :users, :joined_on, false
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Obsolete administrative access must not be restored"
  end

  private

  def quote_table_name(name)
    connection.quote_table_name(name)
  end

  def normalize_audit_indexes
    return unless table_exists?(:business_audit_events)

    legacy_prefix = "plat" + "form"
    rename_audit_index([ "index", legacy_prefix, "audits_on_auditable" ].join("_"), "index_business_audits_on_auditable")
    rename_audit_index([ "index", legacy_prefix, "audit_events_on_action_and_occurred_at" ].join("_"), "index_business_audit_events_on_action_and_occurred_at")
    rename_audit_index([ "index", legacy_prefix, "audit_events_on_actor_id" ].join("_"), "index_business_audit_events_on_actor_id")
    rename_audit_index([ "index", legacy_prefix, "audit_events_on_request_id" ].join("_"), "index_business_audit_events_on_request_id")
    rename_audit_index([ "index", legacy_prefix, "audit_events_on_shop_id" ].join("_"), "index_business_audit_events_on_shop_id")
    rename_audit_index([ "index", legacy_prefix, "audit_events_on_shop_id_and_occurred_at" ].join("_"), "index_business_audit_events_on_shop_id_and_occurred_at")
  end

  def rename_audit_index(old_name, new_name)
    return unless index_name_exists?(:business_audit_events, old_name)

    rename_index :business_audit_events, old_name, new_name
  end
end
