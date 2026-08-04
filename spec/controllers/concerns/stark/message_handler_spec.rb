require 'rails_helper'

RSpec.describe Stark::MessageHandler do
  let(:handler) do
    Class.new do
      include Stark::MessageHandler

      attr_accessor :current_conversation, :event_data, :agent_bot

      def initialize
        @current_conversation = nil
        @event_data = {}
        @agent_bot = nil
      end
    end.new
  end

  describe '#response_valid?' do
    it 'returns true when response has content' do
      expect(handler.response_valid?({ 'content' => 'Hello' })).to be true
    end

    it 'returns true when response has action' do
      expect(handler.response_valid?({ 'action' => 'some_action' })).to be true
    end

    it 'returns true when response has attachments' do
      expect(handler.response_valid?({ 'attachments' => [{ 'url' => 'http://example.com' }] })).to be true
    end

    it 'returns false when response is empty' do
      expect(handler.response_valid?({})).to be false
    end
  end
end
