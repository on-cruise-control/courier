require 'rails_helper'

RSpec.describe ConversationHandoff::SendHandoffNotificationsJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let(:emails) { ['agent@dealership.com'] }
  let(:customer_data) { { 'name' => 'Jane Doe', 'phone' => '+9876543210', 'email' => 'jane@example.com' } }

  let(:summary_service) { instance_double(Conversations::SummaryService) }
  let(:mailer_double) { instance_double(ActionMailer::MessageDelivery) }
  let(:sms_service) { instance_double(Sms::HandoffNotificationService) }

  describe '#perform' do
    context 'when conversation exists with emails' do
      before do
        allow(Conversations::SummaryService).to receive(:new).with(
          conversation: conversation, force_refresh: true, skip_rate_limit: true
        ).and_return(summary_service)
        allow(summary_service).to receive(:perform)

        allow(AdministratorNotifications::ConversationHandoffMailer).to receive(:notify_handoff).with(
          conversation, customer_data, { to: emails }
        ).and_return(mailer_double)
        allow(mailer_double).to receive(:deliver_later)

        allow(Sms::HandoffNotificationService).to receive(:new).with(
          conversation, emails: emails, customer_data: customer_data
        ).and_return(sms_service)
        allow(sms_service).to receive(:perform)
      end

      it 'calls Conversations::SummaryService' do
        described_class.perform_now(conversation, customer_data, emails)
        expect(Conversations::SummaryService).to have_received(:new).with(
          conversation: conversation, force_refresh: true, skip_rate_limit: true
        )
        expect(summary_service).to have_received(:perform)
      end

      it 'sends handoff notification email' do
        described_class.perform_now(conversation, customer_data, emails)
        expect(AdministratorNotifications::ConversationHandoffMailer).to have_received(:notify_handoff).with(
          conversation, customer_data, { to: emails }
        )
        expect(mailer_double).to have_received(:deliver_later)
      end

      it 'sends SMS handoff notification' do
        described_class.perform_now(conversation, customer_data, emails)
        expect(Sms::HandoffNotificationService).to have_received(:new).with(
          conversation, emails: emails, customer_data: customer_data
        )
        expect(sms_service).to have_received(:perform)
      end
    end

    context 'when conversation is nil' do
      it 'returns early without errors' do
        expect(Conversations::SummaryService).not_to receive(:new)
        expect(AdministratorNotifications::ConversationHandoffMailer).not_to receive(:notify_handoff)
        expect(Sms::HandoffNotificationService).not_to receive(:new)

        described_class.perform_now(nil, customer_data, emails)
      end
    end
  end
end
