class StaffInvitationsController < ApplicationController
  before_action :set_invitation, only: :destroy

  def index
    authorize StaffInvitation
    @invitations = policy_scope(StaffInvitation).includes(:branch, :invited_by).recent_first
    @invitation = current_shop.staff_invitations.new(branch: current_branch, expires_at: 7.days.from_now)
  end

  def create
    @invitation = current_shop.staff_invitations.new(invitation_params.merge(invited_by: current_user))
    authorize @invitation
    revoke_expired_invitation
    if @invitation.save
      StaffInvitationMailer.with(invitation: @invitation, token: @invitation.raw_token).invite.deliver_later
      BusinessAuditEvent.record!(action: "staff_invitation.created", shop: current_shop, actor: current_user, auditable: @invitation)
      redirect_to staff_invitations_path, notice: t("saas.invitation_sent")
    else
      @invitations = policy_scope(StaffInvitation).includes(:branch, :invited_by).recent_first
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    authorize @invitation, :revoke?
    @invitation.revoke!(current_user)
    redirect_to staff_invitations_path, notice: t("saas.invitation_revoked")
  rescue StaffInvitation::InvalidInvitation => error
    redirect_to staff_invitations_path, alert: error.message
  end

  private

  def set_invitation
    @invitation = policy_scope(StaffInvitation).find(params[:id])
  end

  def invitation_params
    params.require(:staff_invitation).permit(:email, :role, :branch_id, :expires_at).tap do |attributes|
      attributes[:branch_id] = policy_scope(Branch).find(attributes[:branch_id]).id
    end
  end

  def revoke_expired_invitation
    email = params.dig(:staff_invitation, :email).to_s.strip.downcase
    current_shop.staff_invitations.where(email: email, accepted_at: nil, revoked_at: nil, expires_at: ..Time.current)
      .update_all(revoked_at: Time.current, updated_at: Time.current)
  end
end
