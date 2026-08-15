# frozen_string_literal: true

class SchedulePolicy < Struct.new(:user, :schedule)
  def show?
    user.present? && user.active?
  end

  def filter_staff?
    user.owner? || user.manager?
  end
end
