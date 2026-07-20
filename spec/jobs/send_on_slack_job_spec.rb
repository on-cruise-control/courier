require 'rails_helper'

RSpec.describe SendOnSlackJob do
  let(:message) { create(:message) }
  let(:hook) { create(:integrations_hook) }
  let(:slack_service) { instance_double('Integrations::Slack::SendOnSlackService') }

  describe '#perform' do
    it 'calls Integrations::Slack::SendOnSlackService with the message and hook' do
      allow(Integrations::Slack::SendOnSlackService).to receive(:new).with(message: message, hook: hook).and_return(slack_service)
      allow(slack_service).to receive(:perform)

      described_class.perform_now(message, hook)

      expect(Integrations::Slack::SendOnSlackService).to have_received(:new).with(message: message, hook: hook)
      expect(slack_service).to have_received(:perform)
    end
  end
end
