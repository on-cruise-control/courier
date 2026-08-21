class Api::V1::Widget::VehicleContactsController < Api::V1::Widget::BaseController
  skip_before_action :set_contact
  wrap_parameters false

  def create
    account = @current_account

    if account.booking_emails.blank? && !GlobalConfigService.default_emails_present?
      return render json: { error: 'No booking emails configured' }, status: :unprocessable_entity
    end

    VehicleContactMailer.with(
      account: account,
      name: params[:name],
      phone: params[:phone],
      email: params[:email],
      message: params[:message],
      vehicle_title: params[:vehicle_title]
    ).contact_notification.deliver_later

    create_booking(account)

    render json: { success: true }
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end

  private

  def create_booking(account)
    conversation = account.conversations.find_by(id: params[:conversation_id])
    return unless conversation

    vehicle_title = params[:vehicle_title].presence || 'a vehicle'
    summary = build_summary(vehicle_title)

    Dealership::BookingCreateService.new(
      conversation,
      force: true,
      type: 'booking',
      summary: summary
    ).perform
  rescue StandardError => e
    Rails.logger.error("[VehicleContact] Booking failed for conversation #{params[:conversation_id]}: #{e.message}")
  end

  def build_summary(vehicle_title)
    parts = ["A customer submitted a contact request for #{vehicle_title}."]
    parts << "Name: #{params[:name]}." if params[:name].present?
    parts << "Phone: #{params[:phone]}." if params[:phone].present?
    parts << "Email: #{params[:email]}." if params[:email].present?
    parts << "Message: #{params[:message]}." if params[:message].present?
    parts.join(' ')
  end
end
