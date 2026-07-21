require 'rails_helper'

RSpec.describe SlackNotifierService do
  describe '.call' do
    context 'when SLACK_BOT_TOKEN is not present' do
      before do
        allow(ENV).to receive(:[]).with('SLACK_BOT_TOKEN').and_return(nil)
        allow(ENV).to receive(:[]).with('SLACK_DEFAULT_CHANNEL').and_return(nil)
      end

      it 'logs error and returns nil' do
        expect(Rails.logger).to receive(:error).with('SLACK_BOT_TOKEN is missing in environment variables')
        result = described_class.call(text: 'Test message')
        expect(result).to be_nil
      end
    end

    context 'when SLACK_BOT_TOKEN is present' do
      let(:slack_token) { 'test-slack-token' }
      let(:mock_response) { double('response', parsed_response: { 'ok' => true }, body: 'ok') }

      before do
        allow(ENV).to receive(:[]).with('SLACK_BOT_TOKEN').and_return(slack_token)
        allow(ENV).to receive(:[]).with('SLACK_DEFAULT_CHANNEL').and_return('#general')
        allow(HTTParty).to receive(:post).and_return(mock_response)
      end

      it 'sends message to Slack API' do
        expect(HTTParty).to receive(:post).with(
          'https://slack.com/api/chat.postMessage',
          hash_including(
            headers: hash_including(
              'Authorization' => "Bearer #{slack_token}",
              'Content-Type' => 'application/json'
            ),
            body: {
              channel: '#general',
              text: 'Test message'
            }.to_json
          )
        )
        described_class.call(text: 'Test message')
      end

      context 'with custom channel' do
        before do
          allow(ENV).to receive(:[]).with('SLACK_DEFAULT_CHANNEL').and_return(nil)
        end

        it 'uses provided channel' do
          expect(HTTParty).to receive(:post).with(
            'https://slack.com/api/chat.postMessage',
            hash_including(
              body: {
                channel: '#custom',
                text: 'Test message'
              }.to_json
            )
          )
          described_class.call(text: 'Test message', channel: '#custom')
        end
      end

      context 'with impact report' do
        before do
          allow(ENV).to receive(:[]).with('SLACK_IMPACT_REPORT_CHANNEL').and_return('#impact-reports')
        end

        it 'uses impact report channel' do
          expect(HTTParty).to receive(:post).with(
            'https://slack.com/api/chat.postMessage',
            hash_including(
              body: {
                channel: '#impact-reports',
                text: 'Test message'
              }.to_json
            )
          )
          described_class.call(text: 'Test message', is_impact_report: true)
        end
      end

      context 'when API returns error' do
        let(:mock_response) { double('response', parsed_response: { 'ok' => false }, body: 'error') }

        it 'logs error' do
          expect(Rails.logger).to receive(:error).with('Slack API Error: error')
          described_class.call(text: 'Test message')
        end
      end
    end
  end
end
