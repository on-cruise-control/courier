require 'rails_helper'

RSpec.describe Instagram::BaseMessageText do
  subject { TestMessageText.new(messaging, channel) }

  let(:channel) { double('Channel') }
  let(:messaging) { { sender: { id: '123' }, recipient: { id: '456' }, message: {} } }

  # Use a concrete subclass for testing abstract behavior
  class TestMessageText < Instagram::BaseMessageText
    def ensure_contact(_contact_id); end
    def create_message; end
  end

  describe '#perform' do
    it 'does not raise error when inbox is present' do
      allow_any_instance_of(Instagram::BaseMessageText).to receive(:inbox_channel).and_return(true)
      expect { subject.perform }.not_to raise_error
    end
  end

  describe 'abstract methods' do
    it 'raises NotImplementedError if not overridden' do
      abstract = Instagram::BaseMessageText.new(messaging, channel)
      expect { abstract.send(:ensure_contact, 'id') }.to raise_error(NotImplementedError)
      expect { abstract.send(:create_message) }.to raise_error(NotImplementedError)
    end
  end
end
