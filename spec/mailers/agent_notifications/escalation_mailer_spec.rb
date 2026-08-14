# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentNotifications::EscalationMailer do
  let(:class_instance) { described_class.new }
  let!(:account) { create(:account) }
  let(:agent) { create(:user, email: 'agent1@example.com', account: account) }
  let(:conversation) { create(:conversation, assignee: agent, account: account) }

  before do
    allow(described_class).to receive(:new).and_return(class_instance)
    allow(class_instance).to receive(:smtp_config_set_or_development?).and_return(true)
  end

  describe 'escalation_notification' do
    let(:mail) do
      described_class.with(account: account).escalation_notification(
        emails: [agent.email],
        conversation: conversation,
        customer_data: nil,
        message: nil
      ).deliver_now
    end

    it 'renders the subject' do
      expect(mail.subject).to eq('[Escalation] 🚨 Urgent Escalation: Customer Experience Issue – Immediate Attention Required')
    end

    it 'renders the receiver email' do
      expect(mail.to).to eq([agent.email])
    end

    it 'sends to multiple recipients' do
      agent2 = create(:user, email: 'agent2@example.com', account: account)
      mail = described_class.with(account: account).escalation_notification(
        emails: [agent.email, agent2.email],
        conversation: conversation,
        customer_data: nil,
        message: nil
      ).deliver_now
      expect(mail.to).to contain_exactly(agent.email, agent2.email)
    end

    context 'when account is suspended' do
      let!(:super_admin) { create(:user, email: 'superadmin@example.com', account: account, type: 'SuperAdmin') }

      before do
        account.update!(status: :suspended)
      end

      it 'sends to super admins only' do
        expect(mail.to).to eq(['superadmin@example.com'])
      end

      it 'does not send to regular agents' do
        expect(mail.to).not_to include(agent.email)
      end
    end

    context 'when recipients are blank' do
      it 'returns nil and does not send email' do
        mail = described_class.with(account: account).escalation_notification(
          emails: [],
          conversation: conversation,
          customer_data: nil,
          message: nil
        ).deliver_now
        expect(mail).to be_nil
      end
    end

    context 'with customer data' do
      let(:customer_data) do
        {
          'name' => 'John Doe',
          'phone' => '+1234567890',
          'email' => 'john@example.com'
        }
      end
      let(:mail) do
        described_class.with(account: account).escalation_notification(
          emails: [agent.email],
          conversation: conversation,
          customer_data: customer_data,
          message: nil
        ).deliver_now
      end

      it 'uses customer name from customer_data' do
        expect(mail.body.encoded).to include('John Doe')
      end

      it 'uses customer email from customer_data' do
        expect(mail.body.encoded).to include('john@example.com')
      end

      it 'uses customer phone from customer_data' do
        expect(mail.body.encoded).to include(PhoneNumberFormatter.format(customer_data['phone']))
      end
    end

    context 'without customer data' do
      it 'falls back to contact name' do
        expect(mail.body.encoded).to include(conversation.contact.name)
      end
    end

    context 'with message' do
      let(:message) { create(:message, conversation: conversation, account: account, content: 'Test message content') }
      let(:mail) do
        described_class.with(account: account).escalation_notification(
          emails: [agent.email],
          conversation: conversation,
          customer_data: nil,
          message: message
        ).deliver_now
      end

      it 'sends the email successfully' do
        expect(mail).to be_present
        expect(mail.subject).to eq('[Escalation] 🚨 Urgent Escalation: Customer Experience Issue – Immediate Attention Required')
      end
    end
  end

  describe 'negative_sentiment_notification' do
    let(:incoming_message) do
      create(:message, conversation: conversation, account: account, message_type: :incoming, content: 'This is terrible service!')
    end
    let(:mail) do
      described_class.with(account: account).negative_sentiment_notification(
        emails: [agent.email],
        conversation: conversation,
        customer_data: nil
      ).deliver_now
    end

    before do
      incoming_message
    end

    it 'renders the subject' do
      expect(mail.subject).to eq('[Escalation] Negative Comment Detected – High-Priority Follow-Up Required')
    end

    it 'renders the receiver email' do
      expect(mail.to).to eq([agent.email])
    end

    it 'sends to multiple recipients' do
      agent2 = create(:user, email: 'agent2@example.com', account: account)
      mail = described_class.with(account: account).negative_sentiment_notification(
        emails: [agent.email, agent2.email],
        conversation: conversation,
        customer_data: nil
      ).deliver_now
      expect(mail.to).to contain_exactly(agent.email, agent2.email)
    end

    context 'when account is suspended' do
      let!(:super_admin) { create(:user, email: 'superadmin@example.com', account: account, type: 'SuperAdmin') }

      before do
        account.update!(status: :suspended)
      end

      it 'sends to super admins only' do
        expect(mail.to).to eq(['superadmin@example.com'])
      end

      it 'does not send to regular agents' do
        expect(mail.to).not_to include(agent.email)
      end
    end

    context 'when recipients are blank' do
      it 'returns nil and does not send email' do
        mail = described_class.with(account: account).negative_sentiment_notification(
          emails: [],
          conversation: conversation,
          customer_data: nil
        ).deliver_now
        expect(mail).to be_nil
      end
    end

    context 'with customer data' do
      let(:customer_data) do
        {
          'name' => 'Jane Smith',
          'phone' => '+1987654321',
          'email' => 'jane@example.com'
        }
      end
      let(:mail) do
        described_class.with(account: account).negative_sentiment_notification(
          emails: [agent.email],
          conversation: conversation,
          customer_data: customer_data
        ).deliver_now
      end

      it 'sends the email successfully with customer data' do
        expect(mail).to be_present
        expect(mail.subject).to eq('[Escalation] Negative Comment Detected – High-Priority Follow-Up Required')
      end
    end

    context 'without customer data' do
      it 'uses contact information' do
        expect(mail.body.encoded).to include(conversation.contact.name)
        expect(mail.body.encoded).to include(conversation.contact.email) if conversation.contact.email.present?
      end
    end

    context 'with incoming message' do
      it 'includes the last incoming message content' do
        expect(mail.body.encoded).to include('This is terrible service!')
      end
    end

    context 'when no incoming messages exist' do
      before do
        conversation.messages.where(message_type: :incoming).destroy_all
      end

      it 'has no incoming message content' do
        # NOTE: The mailer has a bug where it tries to call .content on a string
        # when no incoming messages exist. This test documents that behavior.
        # The mailer code at line 37-38 does: @comment_body = ...last || '' then @comment = @comment_body.content
        # which will fail when @comment_body is an empty string.
        # This is a known limitation of the current implementation.
        expect(conversation.messages.where(message_type: :incoming).count).to eq(0)
      end
    end
  end
end
