class ScheduleHandoffLabelChangeJob < ApplicationJob
  queue_as :high

  def perform(conversation)
    return if conversation.blank?

    conversation.update_columns(last_handoff_at: nil) # rubocop:disable Rails/SkipsModelValidations
  end
end
