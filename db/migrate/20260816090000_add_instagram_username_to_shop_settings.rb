class AddInstagramUsernameToShopSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_settings, :instagram_username, :string
  end
end
