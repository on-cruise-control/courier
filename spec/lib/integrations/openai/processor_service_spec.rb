require 'rails_helper'

RSpec.describe Integrations::Openai::ProcessorService do
  subject(:service) { described_class.new(hook: hook, event: event) }

  let(:openai_models_response) do
    {
      data: [
        { id: 'gpt-4o-mini', object: 'model', owned_by: 'openai' }
      ]
    }.to_json
  end

  let(:api_response) do
    {
      message: 'This is a reply from openai.',
      usage: {
        prompt_tokens: 50,
        completion_tokens: 20,
        total_tokens: 70
      },
      request_messages: [
        {
          role: 'system',
          content: 'You are a helpful support agent.'
        },
        {
          role: 'user',
          content: 'This is a test'
        }
      ]
    }
  end

  let(:account) { create(:account) }
  let(:hook) { create(:integrations_hook, :openai, account: account) }

  before do
    stub_request(:get, 'https://api.openai.com/v1/models')
      .to_return(status: 200, body: openai_models_response, headers: {})

    stub_request(:get, 'https://custom.azure.com/v1/models')
      .to_return(status: 200, body: openai_models_response, headers: {})

    allow_any_instance_of(described_class)
      .to receive(:make_api_call)
      .and_return(api_response)
  end

  describe '#perform' do
    describe 'text transformation operations' do
      shared_examples 'text transformation operation' do |event_name|
        let(:event) do
          {
            'name' => event_name,
            'data' => {
              'content' => 'This is a test',
              'conversation_display_id' => nil
            }
          }
        end

        it 'returns the transformed text' do
          result = service.perform
          # expect(result).to be_a(Hash)
          expect(result[:message]).to eq('This is a reply from openai.')
        end

        it 'sends the request body to the LLM API' do
          allow(service).to receive(:make_api_call).and_return(api_response)
          expect(service.send(:build_api_call_body, described_class::AGENT_INSTRUCTION || 'You are a helpful support agent.', 'This is a test'))
            .to include('This is a test')
        end
      end

      it_behaves_like 'text transformation operation', 'fix_spelling_grammar'
    end

    describe 'conversation-based operations' do
      let!(:conversation) { create(:conversation, account: account) }

      before do
        create(
          :message,
          account: account,
          conversation: conversation,
          message_type: :incoming,
          content: 'hello agent'
        )

        create(
          :message,
          account: account,
          conversation: conversation,
          message_type: :outgoing,
          content: 'hello customer'
        )
      end

      context 'with reply_suggestion event' do
        let(:event) do
          {
            'name' => 'reply_suggestion',
            'data' => {
              'conversation_display_id' => conversation.display_id
            }
          }
        end

        it 'returns the suggested reply' do
          result = service.perform
          expect(result[:message]).to eq('This is a reply from openai.')
        end

        it 'sends conversation history to the API' do
          expect(service)
            .to receive(:make_api_call)
            .with(a_string_including('hello agent', 'hello customer'))
            .and_return(api_response)

          service.perform
        end
      end

      context 'with summarize event' do
        let(:event) do
          {
            'name' => 'summarize',
            'data' => {
              'conversation_display_id' => conversation.display_id
            }
          }
        end

        it 'returns the summary' do
          result = service.perform
          expect(result[:message]).to eq('This is a reply from openai.')
        end

        it 'sends formatted conversation' do
          expect(service)
            .to receive(:make_api_call)
            .with(a_string_including('hello agent', 'hello customer'))
            .and_return(api_response)

          service.perform
        end
      end

      context 'with label_suggestion event and no labels' do
        let(:event) do
          {
            'name' => 'label_suggestion',
            'data' => {
              'conversation_display_id' => conversation.display_id
            }
          }
        end

        it 'returns nil' do
          expect(service.perform).to be_nil
        end
      end
    end

    describe 'edge cases' do
      let(:event) do
        {
          'name' => 'unknown',
          'data' => {}
        }
      end

      it 'returns nil for unknown events' do
        expect(service.perform).to be_nil
      end
    end

    describe 'response structure' do
      let(:event) do
        {
          'name' => 'fix_spelling_grammar',
          'data' => {
            'content' => 'test message'
          }
        }
      end

      before do
        allow(service).to receive(:make_api_call).and_return(api_response)
      end

      it 'returns message and usage information' do
        result = service.perform

        expect(result[:message]).to eq('This is a reply from openai.')

        expect(result[:usage][:prompt_tokens]).to eq(50)
        expect(result[:usage][:completion_tokens]).to eq(20)
        expect(result[:usage][:total_tokens]).to eq(70)
      end

      it 'includes request messages' do
        result = service.perform

        expect(result[:request_messages]).to be_an(Array)
        expect(result[:request_messages].size).to eq(2)
      end
    end
  end
end
