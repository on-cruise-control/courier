require 'rails_helper'

RSpec.describe SendCommentReplyJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox,
                          additional_attributes: { 'type' => 'instagram_comments', 'comment_id' => 'comment_123' })
  end

  describe '#perform' do
    context 'when contact_inbox is not found' do
      it 'returns without action' do
        expect(Rails.logger).to receive(:error).with(/ContactInbox not found/)
        described_class.perform_now(nil, conversation)
      end
    end

    context 'when comment_id is blank' do
      it 'returns without action' do
        conversation.update!(additional_attributes: {})
        expect(Rails.logger).to receive(:error).with(/Missing comment_id/)
        described_class.perform_now(contact_inbox.id, conversation)
      end
    end

    context 'when Stark API fails to generate a reply' do
      it 'returns without action' do
        allow(Stark::CommentAnalysisService).to receive_message_chain(:new, :analyze)
          .and_return({ status: 'failure', reply: nil })
        expect(Rails.logger).to receive(:warn).with(/Stark API failed/)
        described_class.perform_now(contact_inbox.id, conversation)
      end
    end

    context 'when type is unsupported' do
      it 'logs a warning' do
        conversation.update!(additional_attributes: conversation.additional_attributes.merge('type' => 'unknown_type'))
        allow(Stark::CommentAnalysisService).to receive_message_chain(:new, :analyze)
          .and_return({ status: 'success', reply: 'Great reply!', sentiment_label: 'Positive', stark_comment_id: 'stark_123' })
        expect(Rails.logger).to receive(:warn).with(/Unsupported comment type/)
        described_class.perform_now(contact_inbox.id, conversation)
      end
    end
  end
end
