require 'rails_helper'

RSpec.describe NegativeSentimentEscalationJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:emails) { ['agent1@example.com', 'agent2@example.com'] }

  let(:summary_service) { instance_double(Conversations::SummaryService) }
  let(:sms_service) { instance_double(Sms::NegativeSentimentEscalationService) }
  let(:mailer_double) { instance_double(ActionMailer::MessageDelivery) }

  describe '#perform' do
    context 'when conversation exists' do
      before do
        allow(Conversations::SummaryService).to receive(:new).with(
          conversation: conversation,
          force_refresh: true,
          skip_rate_limit: true
        ).and_return(summary_service)
        allow(summary_service).to receive(:perform).and_return({ success: true })

        allow(AgentNotifications::EscalationMailer).to receive(:negative_sentiment_notification).with(
          emails: emails,
          conversation: conversation
        ).and_return(mailer_double)
        allow(mailer_double).to receive(:deliver_now)

        allow(Sms::NegativeSentimentEscalationService).to receive(:new).with(
          conversation: conversation,
          emails: emails
        ).and_return(sms_service)
        allow(sms_service).to receive(:perform)
      end

      it 'calls Conversations::SummaryService with correct arguments' do
        described_class.perform_now(conversation.id, emails)
        expect(Conversations::SummaryService).to have_received(:new).with(
          conversation: conversation,
          force_refresh: true,
          skip_rate_limit: true
        )
        expect(summary_service).to have_received(:perform)
      end

      it 'sends negative sentiment notification email via mailer' do
        described_class.perform_now(conversation.id, emails)
        expect(AgentNotifications::EscalationMailer).to have_received(:negative_sentiment_notification).with(
          emails: emails,
          conversation: conversation
        )
        expect(mailer_double).to have_received(:deliver_now)
      end

      it 'calls Sms::NegativeSentimentEscalationService' do
        described_class.perform_now(conversation.id, emails)
        expect(Sms::NegativeSentimentEscalationService).to have_received(:new).with(
          conversation: conversation,
          emails: emails
        )
        expect(sms_service).to have_received(:perform)
      end
    end

    context 'when conversation does not exist' do
      it 'returns early without raising error' do
        expect(Conversations::SummaryService).not_to receive(:new)
        expect(AgentNotifications::EscalationMailer).not_to receive(:negative_sentiment_notification)
        expect(Sms::NegativeSentimentEscalationService).not_to receive(:new)

        expect do
          described_class.perform_now(999_999, emails)
        end.not_to raise_error
      end
    end
  end
end
