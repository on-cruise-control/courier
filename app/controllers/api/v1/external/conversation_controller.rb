class Api::V1::External::ConversationController < Api::BaseController
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100
  HARDCODED_TOKEN = '550e8400-e29b-41d4-a716-446655440000'.freeze
  skip_before_action :authenticate_user!
  before_action :authenticate_token

  def messages
    conversation = Conversation.find(params[:conversation_id])
    @messages = fetch_paginated_messages(conversation)

    render json: build_success_response, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      status_code: 404,
      error: 'Conversation not found'
    }, status: :not_found
  end

  private

  def per_page_param
    (params[:per_page] || DEFAULT_PER_PAGE).to_i.clamp(1, MAX_PER_PAGE)
  end

  def authenticate_by_access_token?
    false
  end

  def authenticate_token
    token = request.headers['Authorization']&.split(' ')&.last
    return if token == HARDCODED_TOKEN

    render json: {
      success: false,
      status_code: 401,
      error: 'Unauthorized'
    }, status: :unauthorized
  end

  def fetch_paginated_messages(conversation)
    conversation.messages
                .select(:id, :conversation_id, :message_type, :content)
                .page(params[:page])
                .per(per_page_param)
  end

  def serialize_message(msg)
    {
      conversation_id: msg.conversation_id,
      message_type: msg.message_type == 'outgoing' ? 'outgoing' : 'incoming',
      content: msg.content
    }
  end

  def build_success_response
    {
      success: true,
      status_code: 200,
      data: {
        messages: @messages.map { |msg| serialize_message(msg) },
        meta: {
          total_count: @messages.total_count,
          current_page: @messages.current_page,
          per_page: @messages.limit_value,
          total_pages: @messages.total_pages
        }
      }
    }
  end
end
