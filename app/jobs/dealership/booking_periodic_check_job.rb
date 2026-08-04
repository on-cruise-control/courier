# frozen_string_literal: true

class Dealership::BookingPeriodicCheckJob < ApplicationJob
  queue_as :low

  def perform(conversation_id)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation
    return unless conversation.additional_attributes['booking_api_job_id'] == provider_job_id

    Dealership::BookingCreateService.new(conversation).perform
  end
end
