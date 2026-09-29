# frozen_string_literal: true

class Ga4AnalyticsListener < BaseListener
  def conversation_created(event)
    conversation, account = extract_conversation_and_account(event)
    inbox = conversation.inbox
    comm_type = Analytics::CommTypeResolver.for(inbox)
    # Widget conversations are already tracked client-side
    return if comm_type.blank? || comm_type == 'widget' || conversation.contact.blank?

    Analytics::Ga4EventService.new(
      account: account,
      event_name: 'asc_comm_engagement',
      client_id: "contact-#{conversation.contact.id}",
      params: {
        event_action: 'conversation_created',
        comm_type: comm_type,
        event_platform: comm_type,
        comm_status: 'engaged',
        conversation_id: conversation.id,
        inbox_id: inbox.id
      }
    ).perform
  end
end
