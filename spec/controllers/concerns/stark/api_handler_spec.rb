require 'rails_helper'

RSpec.describe Stark::ApiHandler do
  let(:account) { create(:account, dealership_id: '550e8400-e29b-41d4-a716-446655440000') }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }

  let(:handler) do
    Class.new do
      include Stark::ApiHandler
      include Stark::Validator

      attr_accessor :agent_bot, :conversation

      def initialize
        @agent_bot = OpenStruct.new(outgoing_url: 'http://example.com/bot')
        @conversation = nil
      end

      def logger
        @logger ||= Logger.new(nil)
      end

      def log_and_notify_slack(message)
        logger.error(message)
      end
    end.new
  end

  before do
    handler.conversation = conversation
    allow(SlackNotifierService).to receive(:call)
  end

  describe '#get_stark_response' do
    context 'when dealership_id is invalid' do
      before do
        allow(conversation.account).to receive(:dealership_id).and_return(nil)
      end

      it 'returns nil' do
        result = handler.get_stark_response(conversation, 'Hello')
        expect(result).to be_nil
      end
    end

    context 'when the API returns a 200 response' do
      before do
        stub_request(:post, 'http://example.com/bot')
          .to_return(
            status: 200,
            body: {
              'metadata' => { 'status_code' => 200 },
              'body' => {
                'data' => {
                  'answer' => 'Hello!',
                  'stop_follow_up' => false,
                  'attachments' => [],
                  'metadata' => {},
                  'is_spam' => false,
                  'is_booking_created' => false,
                  'customer' => {}
                }
              }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns the parsed response' do
        result = handler.get_stark_response(conversation, 'Hello')
        expect(result).to be_a(Hash)
        expect(result['content']).to eq('Hello!')
      end
    end

    context 'when the API returns a 400 error' do
      before do
        stub_request(:post, 'http://example.com/bot')
          .to_return(
            status: 200,
            body: {
              'metadata' => { 'status_code' => 400 },
              'body' => { 'message' => 'Bad request', 'data' => {} }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns nil' do
        result = handler.get_stark_response(conversation, 'Hello')
        expect(result).to be_nil
      end
    end

    context 'when the API returns a 500 error' do
      before do
        stub_request(:post, 'http://example.com/bot')
          .to_return(
            status: 200,
            body: {
              'metadata' => { 'status_code' => 500 },
              'body' => { 'message' => 'Server error', 'data' => {} }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns nil' do
        result = handler.get_stark_response(conversation, 'Hello')
        expect(result).to be_nil
      end
    end
  end

  describe '#valid_dealership_id?' do
    it 'returns true for a valid UUID' do
      expect(handler.send(:valid_dealership_id?, '550e8400-e29b-41d4-a716-446655440000')).to be true
    end

    it 'returns false for nil' do
      expect(handler.send(:valid_dealership_id?, nil)).to be false
    end
  end

  describe '#extract_customer_name' do
    let(:contact) { create(:contact, account: account, name: 'John Doe') }

    before do
      allow(handler).to receive(:logger).and_return(Logger.new(nil))
    end

    it 'returns the contact name for unknown platforms' do
      expect(handler.send(:extract_customer_name, contact, 'SMS')).to eq('John Doe')
    end

    it 'returns nil for Website platform without email' do
      expect(handler.send(:extract_customer_name, contact, 'Website')).to be_nil
    end

    it 'returns name for Website platform with email' do
      contact.update(email: 'john@example.com')
      expect(handler.send(:extract_customer_name, contact, 'Website')).to eq('John Doe')
    end
  end
end
