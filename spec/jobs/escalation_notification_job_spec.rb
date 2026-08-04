require 'rails_helper'

RSpec.describe EscalationNotificationJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:emails) { ['agent1@example.com', 'agent2@example.com'] }
  let(:customer_data) { { 'name' => 'John Doe', 'phone' => '+1234567890', 'email' => 'john@example.com' } }
  let(:message) { create(:message, conversation: conversation, content: 'Test message') }

  let(:summary_service) { instance_double(Conversations::SummaryService) }
  let(:sms_service) { instance_double(Sms::EscalationNotificationService) }
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

        allow(AgentNotifications::EscalationMailer).to receive(:escalation_notification).with(
          emails: emails,
          conversation: conversation,
          customer_data: customer_data,
          message: message
        ).and_return(mailer_double)
        allow(mailer_double).to receive(:deliver_now)

        allow(Sms::EscalationNotificationService).to receive(:new).with(
          conversation: conversation,
          emails: emails,
          customer_data: customer_data
        ).and_return(sms_service)
        allow(sms_service).to receive(:perform)
      end

      it 'calls Conversations::SummaryService with correct arguments' do
        described_class.perform_now(conversation.id, emails, customer_data, message)
        expect(Conversations::SummaryService).to have_received(:new).with(
          conversation: conversation,
          force_refresh: true,
          skip_rate_limit: true
        )
        expect(summary_service).to have_received(:perform)
      end

      it 'sends escalation email via mailer' do
        described_class.perform_now(conversation.id, emails, customer_data, message)
        expect(AgentNotifications::EscalationMailer).to have_received(:escalation_notification).with(
          emails: emails,
          conversation: conversation,
          customer_data: customer_data,
          message: message
        )
        expect(mailer_double).to have_received(:deliver_now)
      end

      it 'calls Sms::EscalationNotificationService' do
        described_class.perform_now(conversation.id, emails, customer_data, message)
        expect(Sms::EscalationNotificationService).to have_received(:new).with(
          conversation: conversation,
          emails: emails,
          customer_data: customer_data
        )
        expect(sms_service).to have_received(:perform)
      end

      it 'works without optional customer_data and message' do
        allow(Conversations::SummaryService).to receive(:new).with(
          conversation: conversation,
          force_refresh: true,
          skip_rate_limit: true
        ).and_return(summary_service)

        allow(AgentNotifications::EscalationMailer).to receive(:escalation_notification).with(
          emails: emails,
          conversation: conversation,
          customer_data: nil,
          message: nil
        ).and_return(mailer_double)

        allow(Sms::EscalationNotificationService).to receive(:new).with(
          conversation: conversation,
          emails: emails,
          customer_data: nil
        ).and_return(sms_service)

        described_class.perform_now(conversation.id, emails, nil, nil)
        expect(summary_service).to have_received(:perform)
        expect(mailer_double).to have_received(:deliver_now)
        expect(sms_service).to have_received(:perform)
      end
    end

    context 'when conversation does not exist' do
      it 'returns early without raising error' do
        expect(Conversations::SummaryService).not_to receive(:new)
        expect(AgentNotifications::EscalationMailer).not_to receive(:escalation_notification)
        expect(Sms::EscalationNotificationService).not_to receive(:new)

        expect do
          described_class.perform_now(999_999, emails, customer_data, message)
        end.not_to raise_error
      end
    end
  end
end
