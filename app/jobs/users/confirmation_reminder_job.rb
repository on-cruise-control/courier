class Users::ConfirmationReminderJob < ApplicationJob
  queue_as :low

  def perform(user_id, stage)
    user = User.find_by(id: user_id)
    return if user.blank? || user.confirmed?

    AgentNotifications::ConfirmationReminderMailer.reminder(user: user, stage: stage).deliver_now

    self.class.set(wait: 3.days).perform_later(user_id, 'second') if stage == 'first'
  end
end
