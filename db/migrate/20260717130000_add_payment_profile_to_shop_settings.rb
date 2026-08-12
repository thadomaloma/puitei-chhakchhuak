class AddPaymentProfileToShopSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_settings, :upi_id, :string
    add_column :shop_settings, :gpay_number, :string

    add_check_constraint :shop_settings,
      "upi_id IS NULL OR (length(upi_id) >= 5 AND length(upi_id) <= 100)",
      name: "shop_settings_upi_id_length"
    add_check_constraint :shop_settings,
      "gpay_number IS NULL OR gpay_number ~ '^[6-9][0-9]{9}$'",
      name: "shop_settings_gpay_number_format"
  end
end
