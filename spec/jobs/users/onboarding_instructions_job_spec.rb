require 'rails_helper'

RSpec.describe Users::OnboardingInstructionsJob, type: :job do
  let(:account) { create(:account) }
  let(:user) { create(:user, skip_confirmation: false, account: account) }
  let(:mailer_double) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }

  before do
    allow(AgentNotifications::OnboardingInstructionsMailer).to receive(:instructions).and_return(mailer_double)
  end

  describe '#perform' do
    context 'when the user no longer exists' do
      it 'does not send the onboarding instructions email' do
        described_class.perform_now(-1)

        expect(AgentNotifications::OnboardingInstructionsMailer).not_to have_received(:instructions)
      end
    end

    context 'when the user has no account' do
      let(:standalone_user) { create(:user, skip_confirmation: false) }

      it 'does not send the onboarding instructions email' do
        described_class.perform_now(standalone_user.id)

        expect(AgentNotifications::OnboardingInstructionsMailer).not_to have_received(:instructions)
      end
    end

    context 'when the user exists and belongs to an account' do
      it 'sends the onboarding instructions email' do
        described_class.perform_now(user.id)

        expect(AgentNotifications::OnboardingInstructionsMailer).to have_received(:instructions).with(user: user)
        expect(mailer_double).to have_received(:deliver_now)
      end
    end
  end
end
