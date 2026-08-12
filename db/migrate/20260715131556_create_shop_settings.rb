class CreateShopSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :shop_settings do |t|
      t.references :branch, null: false, foreign_key: true, index: { unique: true }
      t.string :shop_name, null: false
      t.string :phone
      t.string :whatsapp_number
      t.string :email
      t.text :address
      t.string :currency, null: false, default: "INR"
      t.string :measurement_unit, null: false, default: "inches"
      t.string :invoice_prefix, null: false, default: "TLR"
      t.decimal :tax_rate, precision: 5, scale: 2, null: false, default: 0
      t.integer :default_delivery_days, null: false, default: 14
      t.jsonb :business_hours, null: false, default: {}
      t.integer :low_stock_threshold, null: false, default: 5
      t.string :locale, null: false, default: "en"

      t.timestamps
    end


    add_check_constraint :shop_settings, "measurement_unit IN ('inches', 'centimetres')", name: "shop_settings_measurement_unit"
    add_check_constraint :shop_settings, "tax_rate >= 0 AND tax_rate <= 100", name: "shop_settings_tax_rate"
    add_check_constraint :shop_settings, "default_delivery_days > 0", name: "shop_settings_delivery_days"
    add_check_constraint :shop_settings, "low_stock_threshold >= 0", name: "shop_settings_low_stock_threshold"
  end
end
