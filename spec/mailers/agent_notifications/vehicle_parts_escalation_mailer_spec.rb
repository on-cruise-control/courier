# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentNotifications::VehiclePartsEscalationMailer do
  let(:class_instance) { described_class.new }
  let!(:account) { create(:account) }
  let(:agent) { create(:user, email: 'parts-lead@example.com', account: account) }
  let(:conversation) { create(:conversation, assignee: agent, account: account) }

  before do
    allow(described_class).to receive(:new).and_return(class_instance)
    allow(class_instance).to receive(:smtp_config_set_or_development?).and_return(true)
    allow_any_instance_of(Conversations::SummaryService).to receive(:perform)
  end

  describe 'escalation_notification' do
    let(:mail) do
      described_class.with(account: account).escalation_notification(
        emails: [agent.email], conversation: conversation, customer_data: nil, message: nil
      ).deliver_now
    end

    it 'renders the subject' do
      expect(mail.subject).to eq('[Vehicle Parts Escalation] 🚨 Urgent Parts Escalation: Customer Experience Issue – Immediate Attention Required')
    end

    it 'renders the receiver email' do
      expect(mail.to).to eq([agent.email])
    end

    it 'mentions the vehicle parts department in the body' do
      expect(mail.body.encoded).to include('vehicle parts department')
    end

    context 'when account is suspended' do
      let!(:super_admin) { create(:user, email: 'superadmin@example.com', account: account, type: 'SuperAdmin') }

      before { account.update!(status: :suspended) }

      it 'sends to super admins only' do
        expect(mail.to).to eq(['superadmin@example.com'])
      end
    end

    context 'when recipients are blank' do
      it 'does not send the email' do
        mail = described_class.with(account: account).escalation_notification(
          emails: [], conversation: conversation, customer_data: nil, message: nil
        ).deliver_now
        expect(mail).to be_nil
      end
    end

    context 'with customer data' do
      let(:customer_data) { { 'name' => 'John Doe', 'phone' => '+1234567890', 'email' => 'john@example.com' } }
      let(:mail) do
        described_class.with(account: account).escalation_notification(
          emails: [agent.email], conversation: conversation, customer_data: customer_data, message: nil
        ).deliver_now
      end

      it 'uses the customer data from the payload' do
        expect(mail.body.encoded).to include('John Doe').and include('john@example.com')
      end
    end

    context 'with an incoming message' do
      let(:mail) do
        described_class.with(account: account).escalation_notification(
          emails: [agent.email], conversation: conversation, customer_data: nil,
          message: 'I ordered brake pads weeks ago and still nothing'
        ).deliver_now
      end

      it 'includes the message content' do
        expect(mail.body.encoded).to include('I ordered brake pads weeks ago and still nothing')
      end
    end
  end
end
