# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AgentNotifications::ConversationHandoffMailer do
  let(:class_instance) { described_class.new }
  let!(:account) { create(:account) }
  let(:agent) { create(:user, email: 'agent1@example.com', account: account) }
  let(:conversation) { create(:conversation, assignee: agent, account: account) }

  before do
    allow(described_class).to receive(:new).and_return(class_instance)
    allow(class_instance).to receive(:smtp_config_set_or_development?).and_return(true)
  end

  describe 'notify_handoff' do
    let(:mail) { described_class.with(account: account).notify_handoff(conversation, nil).deliver_now }

    it 'renders the subject' do
      expect(mail.subject).to eq('[Action required] High-priority conversation requires attention')
    end

    it 'renders the receiver email' do
      expect(mail.to).to eq([agent.email])
    end

    it 'sends to all agents in the account' do
      agent2 = create(:user, email: 'agent2@example.com', account: account)
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

    context 'when account has no agents' do
      let(:conversation_without_agents) { create(:conversation, account: account) }
      let(:mail) { described_class.with(account: account).notify_handoff(conversation_without_agents, nil).deliver_now }

      before do
        account.users.where(type: 'Agent').destroy_all
      end

      it 'returns nil and does not send email' do
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
      let(:mail) { described_class.with(account: account).notify_handoff(conversation, customer_data).deliver_now }

      it 'passes customer data to the mailer' do
        expect(mail.body.encoded).to include('John Doe')
      end
    end

    context 'with instagram conversation' do
      let(:instagram_channel) { create(:channel_instagram, account: account) }
      let(:instagram_inbox) { create(:inbox, channel: instagram_channel, account: account) }
      let(:contact) { create(:contact, account: account) }
      let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: instagram_inbox, account: account) }
      let(:instagram_conversation) { create(:conversation, inbox: instagram_inbox, contact: contact, assignee: agent, account: account) }
      let(:mail) { described_class.with(account: account).notify_handoff(instagram_conversation, nil).deliver_now }

      before do
        contact.update!(additional_attributes: { 'social_instagram_user_name' => 'johndoe' })
      end

      it 'includes instagram profile URL' do
        expect(mail).to be_present
        expect(mail.body.encoded).to include('https://www.instagram.com/johndoe')
      end
    end
  end
end
