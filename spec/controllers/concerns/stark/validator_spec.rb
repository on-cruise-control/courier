require 'rails_helper'

RSpec.describe Stark::Validator do
  # Create a test class that includes the concern
  let(:validator) do
    Class.new do
      include Stark::Validator

      attr_accessor :event_name, :event_data, :agent_bot

      def initialize
        @event_name = 'message.created'
        event_message = OpenStruct.new(incoming?: true, conversation: OpenStruct.new(assignee_id: nil))
        @event_data = { message: event_message }
        @agent_bot = OpenStruct.new(outgoing_url: 'http://example.com/bot')
      end
    end.new
  end

  describe '#can_process_message?' do
    context 'when all conditions are met' do
      it 'returns true' do
        expect(validator.can_process_message?).to be true
      end
    end

    context 'when event name is invalid' do
      before do
        validator.event_name = 'invalid.event'
      end

      it 'returns false' do
        expect(validator.can_process_message?).to be false
      end
    end

    context 'when bot URL is blank' do
      before do
        validator.agent_bot = OpenStruct.new(outgoing_url: '')
      end

      it 'returns false' do
        expect(validator.can_process_message?).to be false
      end
    end

    context 'when message is outgoing' do
      before do
        validator.event_data = { message: OpenStruct.new(incoming?: false) }
      end

      it 'returns false' do
        expect(validator.can_process_message?).to be false
      end
    end

    context 'when conversation is assigned' do
      before do
        validator.event_data = { message: OpenStruct.new(incoming?: true, conversation: OpenStruct.new(assignee_id: 1)) }
      end

      it 'returns false' do
        expect(validator.can_process_message?).to be false
      end
    end
  end

  describe '#valid_event_name?' do
    it 'returns true for message.created' do
      expect(validator.valid_event_name?).to be true
    end

    it 'returns false for other events' do
      validator.event_name = 'other.event'
      expect(validator.valid_event_name?).to be false
    end
  end

  describe '#valid_dealership_id?' do
    it 'returns true for a valid UUID' do
      expect(validator.valid_dealership_id?('550e8400-e29b-41d4-a716-446655440000')).to be true
    end

    it 'returns false for an invalid UUID' do
      expect(validator.valid_dealership_id?('not-a-uuid')).to be false
    end

    it 'returns false for nil' do
      expect(validator.valid_dealership_id?(nil)).to be false
    end

    it 'returns false for blank' do
      expect(validator.valid_dealership_id?('')).to be false
    end
  end
end
