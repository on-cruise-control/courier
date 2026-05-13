class Platform::Api::V1::ConversationsController < PlatformController
  def display_ids
    @conversations = Conversation.where(id: params.require(:conversation_ids))
                                 .select(:id, :display_id)
  end
end
