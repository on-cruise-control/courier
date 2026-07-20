require 'rails_helper'

RSpec.describe Sms::BookingNotificationService do
  let(:account) { create(:account, name: 'Test Dealership') }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account, name: 'John Doe') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: contact) }
  let!(:user) { create(:user, email: 'test@example.com', phone_number: '+1234567890') }
  let(:booking_date) { '2023-10-15 10:00 AM' }

  let(:service) do
    described_class.new(
      conversation: conversation,
      booking_date: booking_date,
      phone: '+1987654321',
      email: 'customer@example.com',
      whatsapp_number: '+1122334455',
      text_number: '+1554433221'
    )
  end

  let(:twilio_client) { instance_double(Twilio::REST::Client) }
  let(:messages) { double('TwilioMessages') }

  around do |example|
    with_modified_env FRONTEND_URL: 'http://localhost:3000' do
      example.run
    end
  end

  before do
    account.update!(booking_emails: ['test@example.com'])
    create(:account_twilio_configuration, account: account, account_sid: 'fake_sid', auth_token: 'fake_token',
                                          phone_number: '+1098765432')
    allow(Twilio::REST::Client).to receive(:new).and_return(twilio_client)
    allow(twilio_client).to receive(:messages).and_return(messages)
    allow(inbox).to receive(:platform_name).and_return('Website')
    allow_any_instance_of(Conversations::SummaryService).to receive(:perform)
  end

  describe '#perform' do
    context 'when sms config is missing' do
      before do
        account.twilio_configuration.destroy
        # has_one association caching means `account.twilio_configuration` would otherwise
        # keep returning the destroyed-but-cached record instead of nil.
        account.reload
      end

      it 'does not send sms' do
        expect(messages).not_to receive(:create)
        service.perform
      end
    end

    context 'when there are no recipients with phone numbers' do
      before do
        user.update!(phone_number: nil)
      end

      it 'does not send sms' do
        expect(messages).not_to receive(:create)
        service.perform
      end
    end

    context 'when config and recipients are valid' do
      it 'sends sms to recipients' do
        expect(messages).to receive(:create).with(
          from: '+1098765432',
          to: '+1234567890',
          body: include('New Booking Scheduled').and(include('John Doe')).and(include('2023-10-15'))
        )
        service.perform
      end
    end

    context 'when twilio raises an error' do
      before do
        allow(messages).to receive(:create).and_raise(Twilio::REST::TwilioError.new('Twilio error'))
      end

      it 'rescues the error and logs it' do
        expect(Rails.logger).to receive(:error).with(/Failed to send booking SMS to/)
        service.perform
      end
    end
  end
end
