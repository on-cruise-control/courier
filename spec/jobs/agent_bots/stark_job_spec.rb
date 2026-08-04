require 'rails_helper'

RSpec.describe AgentBots::StarkJob do
  let(:message) { create(:message) }
  let(:agent_bot) { create(:agent_bot) }
  let(:processor_service) { instance_double(Integrations::Stark::ProcessorService) }

  describe '#perform' do
    it 'calls Integrations::Stark::ProcessorService with the event, hook and message' do
      allow(Integrations::Stark::ProcessorService).to receive(:new).with(
        event_name: 'message.created', hook: agent_bot, event_data: { message: message }
      ).and_return(processor_service)
      allow(processor_service).to receive(:perform)

      described_class.perform_now('message.created', agent_bot, message)

      expect(Integrations::Stark::ProcessorService).to have_received(:new).with(
        event_name: 'message.created', hook: agent_bot, event_data: { message: message }
      )
      expect(processor_service).to have_received(:perform)
    end
  end
end
