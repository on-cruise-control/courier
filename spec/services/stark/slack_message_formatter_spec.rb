require 'rails_helper'

RSpec.describe Stark::SlackMessageFormatter do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account, display_id: 123) }

  around do |example|
    with_modified_env FRONTEND_URL: 'http://localhost:3000' do
      example.run
    end
  end

  describe '.format_retry_failure' do
    let(:error) { StandardError.new('Connection timeout') }

    it 'formats the error message correctly' do
      result = described_class.format_retry_failure(error, conversation, 3)

      expect(result).to include('*🚨 STARK API ERROR*')
      expect(result).to include('after 3 retries')
      expect(result).to include('StandardError')
      expect(result).to include('Connection timeout')
      expect(result).to include(conversation.id.to_s)
      expect(result).to include("http://localhost:3000/app/accounts/#{account.id}/conversations/#{conversation.display_id}")
    end
  end

  describe '.format_http_error' do
    it 'formats http error correctly' do
      result = described_class.format_http_error(400, 'Bad Request', 'Invalid param', conversation)

      expect(result).to include('*🚨 API ERROR*')
      expect(result).to include('`400`')
      expect(result).to include('Bad Request')
      expect(result).to include('Invalid param')
      expect(result).to include("http://localhost:3000/app/accounts/#{account.id}/conversations/#{conversation.display_id}")
    end
  end

  describe '.format_follow_up_error' do
    it 'formats follow up error correctly' do
      result = described_class.format_follow_up_error(404, 'Not Found', nil, conversation, 2)

      expect(result).to include('*🚨 STARK FOLLOW-UP ERROR*')
      expect(result).to include('`404`')
      expect(result).to include('Not Found')
      expect(result).to include('Follow-up Number:* `2`')
      expect(result).to include("http://localhost:3000/app/accounts/#{account.id}/conversations/#{conversation.display_id}")
    end
  end
end
