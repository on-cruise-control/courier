require 'rails_helper'

RSpec.describe Reauthorizable do
  let(:account) { create(:account) }
  let(:hook) { create(:integrations_hook, account: account, app_id: 'slack') }

  before do
    # Stub mailer to avoid external dependencies
    integrations_mailer = instance_double(AdministratorNotifications::IntegrationsNotificationMailer)
    mailer_response = instance_double(ActionMailer::MessageDelivery, deliver_later: true)
    allow(AdministratorNotifications::IntegrationsNotificationMailer).to receive(:with).and_return(integrations_mailer)
    allow(integrations_mailer).to receive(:slack_disconnect).and_return(mailer_response)
    allow(integrations_mailer).to receive(:dialogflow_disconnect).and_return(mailer_response)
    allow(hook).to receive(:slack?).and_return(true)
    allow(hook).to receive(:dialogflow?).and_return(false)
  end

  describe '#authorization_error!' do
    it 'increments the error count' do
      expect { hook.authorization_error! }.to change { hook.authorization_error_count }.by(1)
    end

    it 'prompts reauthorization when threshold is reached' do
      expect(hook.reauthorization_required?).to be false

      hook.class::AUTHORIZATION_ERROR_THRESHOLD.times { hook.authorization_error! }

      expect(hook.reauthorization_required?).to be true
    end
  end

  describe '#prompt_reauthorization!' do
    it 'sets reauthorization required flag' do
      expect(hook.reauthorization_required?).to be false
      hook.prompt_reauthorization!
      expect(hook.reauthorization_required?).to be true
    end
  end

  describe '#reauthorized!' do
    it 'resets authorization errors' do
      hook.authorization_error!
      hook.prompt_reauthorization!
      expect(hook.reauthorization_required?).to be true
      expect(hook.authorization_error_count).not_to eq 0

      hook.reauthorized!

      expect(hook.authorization_error_count).to eq 0
      expect(hook.reauthorization_required?).to be false
    end
  end
end
