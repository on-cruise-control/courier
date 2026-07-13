require 'rails_helper'

RSpec.describe Channels::TwilioSms::TemplatesSyncJob do
  let(:channel) { create(:channel_twilio_sms) }
  let(:template_sync_service) { instance_double(Twilio::TemplateSyncService) }

  describe '#perform' do
    it 'calls Twilio::TemplateSyncService with the channel' do
      allow(Twilio::TemplateSyncService).to receive(:new).with(channel: channel).and_return(template_sync_service)
      allow(template_sync_service).to receive(:call)

      described_class.perform_now(channel)

      expect(Twilio::TemplateSyncService).to have_received(:new).with(channel: channel)
      expect(template_sync_service).to have_received(:call)
    end
  end
end
