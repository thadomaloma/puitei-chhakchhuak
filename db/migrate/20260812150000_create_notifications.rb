class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :shop, null: false, foreign_key: true
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.references :actor, foreign_key: { to_table: :users }
      t.references :notifiable, polymorphic: true, null: false
      t.integer :notification_type, null: false
      t.string :title, null: false
      t.string :message, null: false
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [ :recipient_id, :notification_type, :notifiable_type, :notifiable_id ],
      unique: true, name: "index_notifications_on_recipient_and_notifiable_and_type"
    add_index :notifications, [ :recipient_id, :read_at ]
    add_check_constraint :notifications, "notification_type >= 0 AND notification_type <= 2", name: "notifications_type_range"
  end
end
