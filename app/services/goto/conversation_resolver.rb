class Goto::ConversationResolver
  pattr_initialize [:inbox!, :phone_number!]

  def perform
    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: phone_number,
      inbox: inbox,
      contact_attributes: { name: TelephoneNumber.parse(phone_number).international_number, phone_number: phone_number }
    ).perform
    [contact_inbox.contact, find_or_create_conversation(contact_inbox)]
  end

  private

  def find_or_create_conversation(contact_inbox)
    conversation = if inbox.lock_to_single_conversation
                     contact_inbox.conversations.last
                   else
                     contact_inbox.conversations.where.not(status: :resolved).last
                   end
    conversation || ::Conversation.create!(account_id: inbox.account_id, inbox_id: inbox.id, contact_id: contact_inbox.contact_id,
                                           contact_inbox_id: contact_inbox.id)
  end
end
