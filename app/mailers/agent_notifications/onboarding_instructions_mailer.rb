class AgentNotifications::OnboardingInstructionsMailer < ApplicationMailer
  def instructions(user:)
    @user = user
    @account = user.account_users.first.account
    ensure_current_account(@account)

    mail(to: user.email, subject: "Welcome to #{@account.name} — what to expect as an agent")
  end
end
