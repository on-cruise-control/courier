require 'rails_helper'

RSpec.describe Base::SendOnChannelService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message) { build_stubbed(:message, conversation: conversation, message_type: :outgoing) }

  describe '#perform' do
    context 'when message is outgoing' do
      context 'when channel is valid' do
        it 'calls perform_reply' do
          service = described_class.new(message: message)
          allow(service).to receive(:channel_class).and_return(inbox.channel.class)
          expect(service).to receive(:perform_reply)
          service.perform
        end
      end

      context 'when channel is invalid' do
        it 'raises error' do
          service = described_class.new(message: message)
          allow(service).to receive(:channel_class).and_return(String)
          allow(service).to receive(:validate_target_channel).and_raise('Invalid channel service was called')
          expect { service.perform }.to raise_error('Invalid channel service was called')
        end
      end
    end

    context 'when message is incoming' do
      let(:message) { build_stubbed(:message, conversation: conversation, message_type: :incoming) }

      it 'does not send message' do
        service = described_class.new(message: message)
        allow(service).to receive(:channel_class).and_return(inbox.channel.class)
        expect(service).not_to receive(:perform_reply)
        service.perform
      end
    end

    context 'when message is private' do
      let(:message) { build_stubbed(:message, conversation: conversation, message_type: :outgoing, private: true) }

      it 'does not send message' do
        service = described_class.new(message: message)
        allow(service).to receive(:channel_class).and_return(inbox.channel.class)
        expect(service).not_to receive(:perform_reply)
        service.perform
      end
    end

    context 'when message originated from channel' do
      let(:message) { build_stubbed(:message, conversation: conversation, message_type: :outgoing, source_id: '123') }

      it 'does not send message to prevent loops' do
        service = described_class.new(message: message)
        allow(service).to receive(:channel_class).and_return(inbox.channel.class)
        expect(service).not_to receive(:perform_reply)
        service.perform
      end
    end
  end
end
