# frozen_string_literal: true

class Api::V1::Accounts::BookingsController < Api::V1::Accounts::BaseController
  def index
    service = Bookings::BookingService.new(current_account.dealership_id)
    result = service.fetch_bookings(booking_params)
    result[:results] = enrich_with_thumbnails(result[:results]) unless booking_params[:export].present?
    render json: result
  end

  def show
    service = Bookings::BookingService.new(current_account.dealership_id)
    result = service.find_booking(params[:id])
    result = result.merge('contact_thumbnail' => contact_thumbnail_for(result['conversation_id'])) if result['conversation_id'].present?
    render json: result
  end

  private

  def enrich_with_thumbnails(bookings)
    return bookings unless bookings.is_a?(Array)

    conversation_ids = bookings.filter_map { |b| b['conversation_id'] }
    thumbnails = thumbnails_by_conversation_id(conversation_ids)
    bookings.map { |b| b.merge('contact_thumbnail' => thumbnails[b['conversation_id'].to_s]) }
  end

  def thumbnails_by_conversation_id(conversation_ids)
    return {} if conversation_ids.blank?

    Conversation.where(id: conversation_ids)
                .includes(:contact)
                .each_with_object({}) do |conv, hash|
      hash[conv.id.to_s] = conv.contact&.avatar_url.presence
    end
  end

  def contact_thumbnail_for(conversation_id)
    conv = Conversation.includes(:contact).find_by(id: conversation_id)
    conv&.contact&.avatar_url.presence
  end

  private

  def booking_params
    params.permit(:page, :page_size, :created_at_after, :created_at_before, :export)
  end
end
