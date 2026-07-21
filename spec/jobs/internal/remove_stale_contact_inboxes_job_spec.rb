require 'rails_helper'

RSpec.describe Internal::RemoveStaleContactInboxesJob do
  describe '#perform' do
    it 'calls the RemoveStaleContactInboxesService' do
      service = instance_double(Internal::RemoveStaleContactInboxesService)
      expect(Internal::RemoveStaleContactInboxesService).to receive(:new).and_return(service)
      expect(service).to receive(:perform)
      described_class.perform_now
    end
  end
end
