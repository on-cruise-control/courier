require 'rails_helper'

RSpec.describe ServiceEscalationNotificationJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:emails) { ['service-lead@example.com'] }
  let(:customer_data) { { 'name' => 'John Doe', 'phone' => '+1234567890', 'email' => 'john@example.com' } }
  let(:message) { create(:message, conversation: conversation, content: 'Your service team damaged my car') }

  let(:summary_service) { instance_double(Conversations::SummaryService) }
  let(:sms_service) { instance_double(Sms::ServiceEscalationNotificationService) }
  let(:mailer_double) { instance_double(ActionMailer::MessageDelivery) }

  before do
    allow(Conversations::SummaryService).to receive(:new).with(
      conversation: conversation, force_refresh: true, skip_rate_limit: true
    ).and_return(summary_service)
    allow(summary_service).to receive(:perform)

    allow(AgentNotifications::ServiceEscalationMailer).to receive(:escalation_notification).and_return(mailer_double)
    allow(mailer_double).to receive(:deliver_now)

    allow(Sms::ServiceEscalationNotificationService).to receive(:new).and_return(sms_service)
    allow(sms_service).to receive(:perform)
  end

  describe '#perform' do
    it 'refreshes the summary, sends the mailer and the sms' do
      described_class.perform_now(conversation.id, emails, customer_data, message)

      expect(summary_service).to have_received(:perform)
      expect(AgentNotifications::ServiceEscalationMailer).to have_received(:escalation_notification).with(
        emails: emails, conversation: conversation, customer_data: customer_data, message: message
      )
      expect(mailer_double).to have_received(:deliver_now)
      expect(Sms::ServiceEscalationNotificationService).to have_received(:new).with(
        conversation: conversation, emails: emails, customer_data: customer_data
      )
      expect(sms_service).to have_received(:perform)
    end

    it 'returns early when the conversation does not exist' do
      expect(Conversations::SummaryService).not_to receive(:new)
      expect do
        described_class.perform_now(999_999, emails, customer_data, message)
      end.not_to raise_error
    end
  end
end
