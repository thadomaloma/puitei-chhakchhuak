class OrderReminderJob < ApplicationJob
  queue_as :default

  def perform
    shop = Shop.current
    remind_due_today(shop)
    remind_overdue(shop)
  end

  private

  def remind_due_today(shop)
    shop.orders.confirmed.where(delivery_date: Date.current).find_each do |order|
      notify_managers(order, :due_today,
        title: I18n.t("notifications.due_today.title"),
        message: I18n.t("notifications.due_today.message", customer: order.customer.full_name, order_number: order.order_number))
    end
  end

  def remind_overdue(shop)
    shop.orders.overdue.find_each do |order|
      notify_managers(order, :overdue,
        title: I18n.t("notifications.overdue.title"),
        message: I18n.t("notifications.overdue.message", customer: order.customer.full_name,
          order_number: order.order_number, date: I18n.l(order.delivery_date, format: :long)))
    end
  end

  def notify_managers(order, type, title:, message:)
    recipients = order.branch.memberships.active.where(role: %w[owner manager]).includes(:user).map(&:user)
    recipients.each do |user|
      Notification.notify_once!(recipient: user, notification_type: type, notifiable: order, title: title, message: message)
    end
  rescue StandardError => e
    Rails.logger.error("OrderReminderJob failed for order #{order.id}: #{e.message}")
  end
end
