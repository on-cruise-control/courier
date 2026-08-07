class Users::OnboardingInstructionsJob < ApplicationJob
  queue_as :low

  def perform(user_id)
    user = User.find_by(id: user_id)
    return if user.blank? || user.account_users.blank?

    AgentNotifications::OnboardingInstructionsMailer.instructions(user: user).deliver_now
  end
end
