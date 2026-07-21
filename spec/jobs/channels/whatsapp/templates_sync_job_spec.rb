require 'rails_helper'

RSpec.describe Channels::Whatsapp::TemplatesSyncJob do
  let(:channel) { create(:channel_whatsapp, sync_templates: false, validate_provider_config: false) }

  describe '#perform' do
    it 'calls sync_templates on the channel' do
      allow(channel).to receive(:sync_templates)
      described_class.perform_now(channel)
      expect(channel).to have_received(:sync_templates)
    end
  end
end
