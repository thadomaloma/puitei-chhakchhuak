class StaffInvitationAcceptancesController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :set_current_tenant
  skip_after_action :verify_authorized
  before_action :set_invitation

  def show
    @user = User.new(email: @invitation.email, name: "") unless user_signed_in?
  end

  def create
    membership = ApplicationRecord.transaction do
      invited_user = user_signed_in? ? current_user : create_invited_user!
      @invitation.accept!(invited_user)
    end
    sign_in membership.user unless user_signed_in?
    redirect_to root_path, notice: t("saas.invitation_accepted", shop: membership.shop.name)
  rescue ActiveRecord::RecordInvalid, StaffInvitation::InvalidInvitation => error
    @user = error.respond_to?(:record) && error.record.is_a?(User) ? error.record : User.new(email: @invitation.email)
    @acceptance_error = error.message
    render :show, status: :unprocessable_content
  end

  private

  def set_invitation
    @token = params[:token].presence || params.dig(:staff_invitation_acceptance, :token)
    @invitation = StaffInvitation.find_by_token(@token)
    raise ActiveRecord::RecordNotFound unless @invitation&.usable?
  end

  def create_invited_user!
    attributes = params.require(:user).permit(:name, :password, :password_confirmation)
    User.create!(attributes.merge(email: @invitation.email, branch: @invitation.branch, role: @invitation.role, active: true))
  end
end
