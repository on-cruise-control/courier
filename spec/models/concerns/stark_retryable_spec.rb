require 'rails_helper'

RSpec.describe StarkRetryable do
  # Create a test class that includes the concern
  before_all do
    # rubocop:disable Lint/ConstantDefinitionInBlock
    # rubocop:disable RSpec/LeakyConstantDeclaration
    TestStarkRetryableClass = Struct.new(:conversation) do
      include StarkRetryable

      MAX_RETRIES = 1
      RETRY_DELAY = 0 # Use 0 delay in tests for speed
    end
    # rubocop:enable Lint/ConstantDefinitionInBlock
    # rubocop:enable RSpec/LeakyConstantDeclaration
  end

  let(:test_instance) { TestStarkRetryableClass.new(nil) }

  describe '#with_stark_retry' do
    context 'when the block succeeds on first try' do
      it 'returns the result of the block' do
        result = test_instance.with_stark_retry { 'success' }
        expect(result).to eq('success')
      end
    end

    context 'when the block fails once then succeeds' do
      it 'retries and returns the result' do
        call_count = 0
        result = test_instance.with_stark_retry do
          call_count += 1
          raise StandardError, 'temporary error' if call_count == 1

          'success'
        end
        expect(result).to eq('success')
        expect(call_count).to eq(2)
      end
    end

    context 'when the block consistently fails' do
      it 'returns nil after max retries' do
        result = test_instance.with_stark_retry { raise StandardError, 'persistent error' }
        expect(result).to be_nil
      end
    end

    context 'when a conversation is provided' do
      let(:account) { create(:account) }
      let(:conversation) { create(:conversation, account: account) }
      let(:test_instance) { TestStarkRetryableClass.new(conversation) }

      it 'creates a handoff message when all retries fail' do
        expect do
          test_instance.with_stark_retry(conversation) { raise StandardError, 'persistent error' }
        end.to change { conversation.messages.count }.by(1)
      end
    end
  end
end
