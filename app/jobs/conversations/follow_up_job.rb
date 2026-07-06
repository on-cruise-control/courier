class Conversations::FollowUpJob < ApplicationJob
  queue_as :default

  def perform(conversation_id, follow_up_number)
    conversation = Conversation.find_by(id: conversation_id)
    return if conversation.nil?
    return if (conversation.is_spam || conversation.stop_follow_up || conversation.assignee_id.present?)
    return unless conversation.can_reply?

    last_message = conversation.messages
                               .not_activity
                               .not_template.last
    return if last_message.incoming?

    # Get follow-up message content from Stark API
    stark_response = Stark::FollowUpService.new(conversation, follow_up_number).get_follow_up_content
    return if stark_response.nil?

    case follow_up_number
    when 1
      create_follow_up_message(conversation, 1, stark_response)
      schedule_next_follow_up(conversation, 2)
    when 2
      create_follow_up_message(conversation, 2, stark_response)
      schedule_next_follow_up(conversation, 3)
    when 3
      create_follow_up_message(conversation, 3, stark_response)
      updated_additional_attributes = (conversation.additional_attributes || {}).merge(
        'follow_up_jids' => nil,
        'follow_up_base_time' => nil,
        'follow_up_schedule_hours' => nil
      )
      conversation.update!(follow_up_jid: nil, additional_attributes: updated_additional_attributes)
    end
  end

  private

  def schedule_next_follow_up(conversation, next_follow_up_number)
    base_time_unix = conversation.additional_attributes&.dig('follow_up_base_time')
    base_time = base_time_unix.present? ? Time.at(base_time_unix.to_i) : Time.current

    schedule_hours = conversation.additional_attributes&.dig('follow_up_schedule_hours') || {}
    default_hours =
      case next_follow_up_number
      when 2 then 5
      when 3 then 22
      else 1
      end
    hours = (schedule_hours[next_follow_up_number.to_s] || default_hours).to_i

    wait_time = [base_time + hours.hours - Time.current, 0].max
    jid = Conversations::FollowUpJob.set(wait: wait_time)
                                    .perform_later(conversation.id, next_follow_up_number).provider_job_id

    updated_additional_attributes = (conversation.additional_attributes || {}).merge(
      'follow_up_jids' => Array(conversation.additional_attributes&.dig('follow_up_jids')).compact + [jid].compact
    )
    conversation.update!(follow_up_jid: jid, additional_attributes: updated_additional_attributes)
  end

  def create_follow_up_message(conversation, follow_up_number, content)
    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :outgoing,
      content: content[:message],
      metadata: content[:metadata],
      content_attributes: {
        follow_up: true,
        follow_up_number: follow_up_number
      },
      sender: conversation.inbox.agent_bot.presence || nil
    )
  end
end
