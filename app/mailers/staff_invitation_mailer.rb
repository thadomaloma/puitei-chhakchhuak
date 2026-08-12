class StaffInvitationMailer < ApplicationMailer
  def invite
    @invitation = params[:invitation]
    @accept_url = accept_staff_invitation_url(token: params[:token])
    mail(to: @invitation.email, subject: I18n.t("saas.invitation_subject", shop: @invitation.shop.name))
  end
end
