require 'rails_helper'

RSpec.describe Channels::TwilioSms::TemplatesSyncSchedulerJob do
  describe '#perform' do
    context 'when no stale channels exist' do
      it 'does not enqueue any sync jobs' do
        expect(Channels::TwilioSms::TemplatesSyncJob).not_to receive(:perform_later)
        described_class.perform_now
      end
    end

    context 'when stale channels exist' do
      it 'enqueues a sync job for each stale channel' do
        channel = create(:channel_twilio_sms, :whatsapp, content_templates_last_updated: 20.minutes.ago)
        expect(Channels::TwilioSms::TemplatesSyncJob).to receive(:perform_later).with(channel)
        described_class.perform_now
      end
    end

    context 'when channel has nil content_templates_last_updated' do
      it 'enqueues a sync job' do
        channel = create(:channel_twilio_sms, :whatsapp, content_templates_last_updated: nil)
        expect(Channels::TwilioSms::TemplatesSyncJob).to receive(:perform_later).with(channel)
        described_class.perform_now
      end
    end

    context 'when channel was recently updated' do
      it 'does not enqueue a sync job' do
        create(:channel_twilio_sms, :whatsapp, content_templates_last_updated: 5.minutes.ago)
        expect(Channels::TwilioSms::TemplatesSyncJob).not_to receive(:perform_later)
        described_class.perform_now
      end
    end
  end
end
