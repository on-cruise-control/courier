class AgentNotifications::ConfirmationReminderMailer < ApplicationMailer
  def reminder(user:, stage:)
    @user = user
    @stage = stage
    account_user = user.account_users.first
    @account = account_user&.account
    @account_name = @account&.name
    @reset_password_token = user.send(:set_reset_password_token)
    ensure_current_account(@account)

    mail(to: user.email, subject: subject_for(stage))
  end

  private

  def subject_for(stage)
    stage == 'second' ? 'Reminder: Your account is still waiting for you' : 'Reminder: Finish setting up your account'
  end
end
