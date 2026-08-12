class NotificationsController < ApplicationController
  def index
    authorize Notification
    @notifications = policy_scope(Notification).includes(:actor, :notifiable).recent_first.limit(30)
    @unread_count = policy_scope(Notification).unread.count
  end

  def read
    notification = policy_scope(Notification).find(params[:id])
    authorize notification, :update?
    notification.mark_read!
    redirect_to notification.notifiable
  end

  def read_all
    authorize Notification, :index?
    policy_scope(Notification).unread.update_all(read_at: Time.current)
    redirect_back fallback_location: notifications_path
  end
end
