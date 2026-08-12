class PurgeLegacyProductBranding < ActiveRecord::Migration[8.1]
  def up
    legacy_brand = [ "Tailor", "Flow" ].join
    legacy_studio = "#{legacy_brand} Studio"

    replace_text(:shops, :name, legacy_studio, "Puitei Chhakchhuak")
    replace_text(:shops, :slug, legacy_brand.downcase, "puitei")
    replace_text(:branches, :name, "#{legacy_brand} Aizawl", "Aizawl")
    replace_text(:shop_settings, :shop_name, legacy_studio, "Puitei Chhakchhuak")
    replace_text(:designs, :description, legacy_studio, "Puitei Chhakchhuak")
    replace_text(:design_shares, :title, legacy_brand, "Puitei Chhakchhuak")
    replace_text(:users, :email, legacy_brand.downcase, "puitei")
    replace_text(:work_shifts, :location, "#{legacy_brand} Aizawl", "Aizawl")
    replace_text(:business_audit_events, :user_agent, legacy_brand, "Puitei Chhakchhuak")
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Removed product branding must not be restored"
  end

  private

  def replace_text(table, column, source, replacement)
    return unless table_exists?(table) && column_exists?(table, column)

    quoted_table = connection.quote_table_name(table)
    quoted_column = connection.quote_column_name(column)
    quoted_source = connection.quote(source)
    quoted_replacement = connection.quote(replacement)

    execute <<~SQL.squish
      UPDATE #{quoted_table}
      SET #{quoted_column} = REPLACE(#{quoted_column}, #{quoted_source}, #{quoted_replacement})
      WHERE #{quoted_column} LIKE '%' || #{quoted_source} || '%'
    SQL
  end
end
