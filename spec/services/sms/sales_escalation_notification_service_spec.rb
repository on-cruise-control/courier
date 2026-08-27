require 'rails_helper'

RSpec.describe Sms::SalesEscalationNotificationService do
  let(:account) { create(:account, name: 'Test Dealership') }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'John Doe') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let!(:user) { create(:user, email: 'sales-lead@example.com', phone_number: '+1234567890') }

  let(:service) { described_class.new(conversation: conversation, emails: ['sales-lead@example.com']) }

  let(:twilio_client) { instance_double(Twilio::REST::Client) }
  let(:messages) { double('TwilioMessages') }

  around do |example|
    with_modified_env FRONTEND_URL: 'http://localhost:3000' do
      example.run
    end
  end

  before do
    create(:account_twilio_configuration, account: account, account_sid: 'fake_sid', auth_token: 'fake_token',
                                          phone_number: '+1098765432')
    allow(Twilio::REST::Client).to receive(:new).and_return(twilio_client)
    allow(twilio_client).to receive(:messages).and_return(messages)
    allow(inbox).to receive(:platform_name).and_return('Website')
    allow_any_instance_of(Conversations::SummaryService).to receive(:perform)
  end

  describe '#perform' do
    it 'sends the sales escalation sms' do
      expect(messages).to receive(:create).with(
        from: '+1098765432',
        to: '+1234567890',
        body: include('Urgent Sales Escalation Required').and(include('John Doe'))
      )
      service.perform
    end

    it 'does nothing when there is no matching user with a phone number' do
      user.update!(phone_number: nil)
      expect(messages).not_to receive(:create)
      service.perform
    end
  end
end
