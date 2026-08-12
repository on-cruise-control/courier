# frozen_string_literal: true

require 'sidekiq/api'

class DealershipListener < BaseListener
  def conversation_created(event)
    conversation, _account = extract_conversation_and_account(event)
    return if conversation.contact.blank?

    Dealership::CustomerCreateService.new(conversation.contact, inbox: conversation.inbox, conversation: conversation).perform
  end

  def message_created(event)
    message, _account = extract_message_and_account(event)
    return unless message.incoming? || message.outgoing?
    return if message.content_attributes['follow_up'] == true

    conversation = message.conversation
    return if conversation.contact.blank?

    inbox = conversation.inbox
    return unless inbox.whatsapp? || inbox.sms? || inbox.twilio?

    conversation.with_lock do
      cancel_existing_booking_job(conversation)
      job = Dealership::BookingPeriodicCheckJob.set(wait: 15.minutes).perform_later(conversation.id)
      conversation.additional_attributes['booking_api_job_id'] = job.provider_job_id
      conversation.save!
    end
  end

  private

  def cancel_existing_booking_job(conversation)
    jid = conversation.additional_attributes['booking_api_job_id']
    return if jid.blank?

    job = ::Sidekiq::ScheduledSet.new.find_job(jid)
    job.delete if job
    conversation.additional_attributes['booking_api_job_id'] = nil
  end
end
