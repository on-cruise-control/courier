require 'rails_helper'

RSpec.describe Stark::UpdateMessageService do
  let(:account) { create(:account) }
  let(:message) { create(:message, account: account, content: 'test') }
  let(:service) { described_class.new(message) }
  let(:stark_endpoint) { 'https://api.stark.example.com' }

  before do
    message.update(metadata: { 'stark_message_id' => 'stark_msg_1' })
    allow(ENV).to receive(:fetch).with('STARK_API_KEY').and_return('fake_api_key')

    # mock AgentBot
    bot = double('AgentBot', outgoing_url: stark_endpoint)
    agent_bots = double('AgentBots', last: bot)
    allow(AgentBot).to receive(:where).with(bot_type: 'stark').and_return(agent_bots)
  end

  describe '#update_human_redirect' do
    context 'when API request is successful' do
      let(:response_body) { { 'metadata' => { 'status_code' => 200 } }.to_json }
      let(:mock_response) { instance_double(HTTParty::Response, body: response_body) }

      before do
        allow(HTTParty).to receive(:put).and_return(mock_response)
      end

      it 'returns success' do
        result = service.update_human_redirect(human_redirect: true)
        expect(result[:status]).to eq('success')
      end
    end

    context 'when API request fails' do
      let(:response_body) do
        {
          'metadata' => { 'status_code' => 500 },
          'body' => { 'message' => 'Internal error' }
        }.to_json
      end
      let(:mock_response) { instance_double(HTTParty::Response, body: response_body) }

      before do
        allow(HTTParty).to receive(:put).and_return(mock_response)
      end

      it 'returns error status' do
        result = service.update_human_redirect(human_redirect: true)
        expect(result[:status]).to eq('error')
        expect(result[:message]).to eq('Internal error')
      end
    end
  end
end
