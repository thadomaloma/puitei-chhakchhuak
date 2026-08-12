class Notification < ApplicationRecord
  tenant_owned_through :notifiable

  belongs_to :recipient, class_name: "User"
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :notifiable, polymorphic: true

  enum :notification_type, { due_today: 0, overdue: 1, work_assigned: 2 }, validate: true

  validates :title, :message, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def read?
    read_at.present?
  end

  def mark_read!
    update!(read_at: Time.current) unless read?
  end

  def self.notify_once!(recipient:, notification_type:, notifiable:, title:, message:, actor: nil)
    create!(recipient: recipient, notification_type: notification_type, notifiable: notifiable,
      title: title, message: message, actor: actor)
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
