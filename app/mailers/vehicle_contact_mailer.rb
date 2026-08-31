class VehicleContactMailer < ApplicationMailer
  def contact_notification
    @account = params[:account]
    @name = params[:name]
    @phone = params[:phone]
    @email = params[:email]
    @message = params[:message]
    @vehicle_title = params[:vehicle_title]

    mail(
      to: @account.booking_emails,
      subject: "New Vehicle Inquiry: #{@vehicle_title}",
      bcc: default_bcc_emails.presence
    )
  end
end
