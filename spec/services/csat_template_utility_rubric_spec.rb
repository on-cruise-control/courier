require 'rails_helper'

RSpec.describe CsatTemplateUtilityRubric do
  # Create a test class that includes the module to test its methods
  let(:test_class) do
    Class.new do
      include CsatTemplateUtilityRubric
      attr_accessor :message, :language

      def initialize(message, language = 'en')
        @message = message
        @language = language
      end

      def sanitized_message
        @message
      end
    end
  end

  let(:instance) { test_class.new('Thank you! Your support ticket has been closed.') }

  describe '#detected_status' do
    context 'with closed status in message' do
      it 'detects closed status' do
        result = instance.send(:detected_status)
        expect(result).to eq('closed')
      end
    end

    context 'with resolved status in message' do
      let(:instance) { test_class.new('Your support ticket has been resolved.') }

      it 'detects resolved status' do
        result = instance.send(:detected_status)
        expect(result).to eq('resolved')
      end
    end

    context 'with no status in message' do
      let(:instance) { test_class.new('Thank you for contacting us.') }

      it 'defaults to closed status' do
        result = instance.send(:detected_status)
        expect(result).to eq('closed')
      end
    end
  end

  describe '#detected_subject' do
    context 'with ticket in message' do
      it 'detects support ticket' do
        result = instance.send(:detected_subject)
        expect(result).to eq('support ticket')
      end
    end

    context 'with conversation in message' do
      let(:instance) { test_class.new('Your conversation has been closed.') }

      it 'detects support conversation' do
        result = instance.send(:detected_subject)
        expect(result).to eq('support conversation')
      end
    end

    context 'with request in message' do
      let(:instance) { test_class.new('Your support request has been closed.') }

      it 'detects support request' do
        result = instance.send(:detected_subject)
        expect(result).to eq('support request')
      end
    end
  end

  describe '#extracted_intro_sentence' do
    context 'with valid intro sentence' do
      let(:instance) { test_class.new('Thank you for contacting us. Your ticket is closed.') }

      it 'extracts the intro sentence' do
        result = instance.send(:extracted_intro_sentence)
        expect(result).to eq('Thank you for contacting us.')
      end
    end

    context 'with marketing language' do
      let(:instance) { test_class.new('Check out our new offers! Your ticket is closed.') }

      it 'returns nil for marketing content' do
        result = instance.send(:extracted_intro_sentence)
        expect(result).to be_nil
      end
    end

    context 'without greeting' do
      let(:instance) { test_class.new('Your ticket has been closed.') }

      it 'returns nil without greeting' do
        result = instance.send(:extracted_intro_sentence)
        expect(result).to be_nil
      end
    end
  end

  describe '#evaluate_criteria' do
    context 'with valid transactional content' do
      it 'evaluates criteria correctly' do
        text = 'Your support ticket has been closed. Reply to this message if you need help.'
        result = instance.send(:evaluate_criteria, text: text, marketing_hits_count: 0)
        expect(result[:trigger]).to be true
        expect(result[:transactional_content]).to be true
        expect(result[:marketing_prohibition]).to be true
        expect(result[:prohibited_content]).to be true
        expect(result[:clarity_and_utility]).to be true
      end
    end

    context 'with marketing content' do
      it 'fails marketing prohibition' do
        text = 'Check out our discount offers! Your ticket is closed.'
        result = instance.send(:evaluate_criteria, text: text, marketing_hits_count: 1)
        expect(result[:marketing_prohibition]).to be false
      end
    end
  end

  describe '#clear_utility_intent?' do
    context 'with support context and actionable step' do
      it 'returns true' do
        text = 'Your support ticket has been closed. Reply to this message if you need help.'
        result = instance.send(:clear_utility_intent?, text)
        expect(result).to be true
      end
    end

    context 'without support context' do
      it 'returns false' do
        text = 'Reply to this message if you need help.'
        result = instance.send(:clear_utility_intent?, text)
        expect(result).to be false
      end
    end

    context 'without actionable next step' do
      it 'returns false' do
        text = 'Your support ticket has been closed.'
        result = instance.send(:clear_utility_intent?, text)
        expect(result).to be false
      end
    end
  end
end
