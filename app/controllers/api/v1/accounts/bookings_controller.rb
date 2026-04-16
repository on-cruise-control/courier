# frozen_string_literal: true

class Api::V1::Accounts::BookingsController < Api::V1::Accounts::BaseController
  def index
    service = Bookings::BookingService.new(current_account.dealership_id)
    result = service.fetch_bookings(booking_params)
    
    render json: result
  end

  def show
    service = Bookings::BookingService.new(current_account.dealership_id)
    result = service.find_booking(params[:id])
    
    render json: result
  end

  private

  def booking_params
    params.permit(:page, :page_size, :created_at_after, :created_at_before)
  end
end
