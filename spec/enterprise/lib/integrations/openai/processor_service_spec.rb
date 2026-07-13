require 'rails_helper'

RSpec.describe Integrations::Openai::ProcessorService do
  subject { described_class.new(hook: hook, event: event) }

  let(:account) { create(:account) }
  let(:hook) { create(:integrations_hook, :openai, account: account) }

  # Mock RubyLLM objects
  let(:mock_chat) { instance_double(RubyLLM::Chat) }
  let(:mock_context) { instance_double(RubyLLM::Context) }
  let(:mock_config) { OpenStruct.new }
  let(:mock_response) do
    instance_double(
      RubyLLM::Message,
      content: 'This is a reply from openai.',
      input_tokens: nil,
      output_tokens: nil
    )
  end
  let(:mock_empty_response) do
    instance_double(
      RubyLLM::Message,
      content: '',
      input_tokens: nil,
      output_tokens: nil
    )
  end

  let(:conversation) { create(:conversation, account: account) }

  before do
    allow(Integrations::Openai::KeyValidator).to receive(:valid?).and_return(true)

    # Default RubyLLM behavior
    allow(RubyLLM).to receive(:context).and_yield(mock_config).and_return(mock_context)
    allow(mock_context).to receive(:chat).and_return(mock_chat)

    allow(mock_chat).to receive(:with_instructions).and_return(mock_chat)
    allow(mock_chat).to receive(:add_message).and_return(mock_chat)
    allow(mock_chat).to receive(:ask).and_return(mock_response)
  end

  describe '#perform' do
    let(:hook) { create(:integrations_hook, :openai, account: account) }

    before do
      # Ensure the hook has an api_key; other settings are read from `hook.settings` directly.
      allow(hook.settings).to receive(:[]).and_call_original
      allow(hook.settings).to receive(:[]).with('api_key').and_return('test-key')

      # Ensure OpenAI base service returns a payload for allowed event names.
      # (Integrations::LlmBaseService#perform returns nil when event name isn't allowed,
      # so we stub the exact method it calls for reply_suggestion.)
    end

    context 'when event name is not one that can be processed' do
      let(:event) { { 'name' => 'unknown', 'data' => {} } }

      it 'returns nil' do
        expect(subject.perform).to be_nil
      end
    end
  end
end
