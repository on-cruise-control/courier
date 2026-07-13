# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Voice::OutboundCallBuilder do
  skip 'channel_voice table does not exist' unless ActiveRecord::Base.connection.data_source_exists?('channel_voice')
  let(:account) { create(:account) }
  let(:channel) { create(:channel_twilio_sms, :with_voice, account: account, phone_number: '+15551230000') }
  let(:inbox) { channel.inbox }
  let(:user) { create(:user, account: account) }
  let(:contact) { create(:contact, account: account, phone_number: '+15550001111') }
  let(:call_sid) { 'CA1234567890abcdef' }

  before do
    allow(Twilio::VoiceWebhookSetupService).to receive(:new)
      .and_return(instance_double(Twilio::VoiceWebhookSetupService, perform: "AP#{SecureRandom.hex(8)}"))
    allow(inbox).to receive(:channel).and_return(channel)
    allow(channel).to receive(:initiate_call).and_return({ call_sid: call_sid })
  end

  describe '.perform!' do
    it 'creates a conversation, Call, and voice_call message' do
      call = nil
      expect do
        call = described_class.perform!(
          account: account,
          inbox: inbox,
          user: user,
          contact: contact
        )
      end.to change(account.conversations, :count).by(1).and change(Call, :count).by(1)

      aggregate_failures do
        expect(call).to be_a(Call)
        expect(call.provider_call_id).to eq(call_sid)
        expect(call.direction).to eq('outgoing')
        expect(call.status).to eq('ringing')
        expect(call.accepted_by_agent_id).to eq(user.id)
        expect(call.conference_sid).to eq("conf_account_#{account.id}_call_#{call.id}")

        voice_message = call.conversation.messages.voice_calls.last
        expect(call.message_id).to eq(voice_message.id)
        expect(voice_message.message_type).to eq('outgoing')
        expect(voice_message.call).to eq(call)
      end
    end

    it 'does not set conversation.identifier or write call state to additional_attributes' do
      conversation_count = account.conversations.count
      inbox_link_count = contact.contact_inboxes.where(inbox_id: inbox.id).count

      call = described_class.perform!(
        account: account,
        inbox: inbox,
        user: user,
        contact: contact
      )

      expect(account.conversations.count).to eq(conversation_count + 1)
      expect(contact.contact_inboxes.where(inbox_id: inbox.id).count).to eq(inbox_link_count + 1)

      conversation = account.conversations.order(created_at: :desc).first.reload
      attrs = conversation.additional_attributes

      aggregate_failures do
        expect(call.provider_call_id).to eq(call_sid)
        expect(conversation.identifier).to be_nil
        expect(attrs).to be_empty

        voice_message = conversation.messages.voice_calls.last
        expect(voice_message.message_type).to eq('outgoing')

        message_data = voice_message.content_attributes['data']

        expect(message_data).to include(
          'call_sid' => call_sid,
          'call_direction' => 'outbound',
          'status' => 'ringing',
          'call_source' => 'twilio'
        )
      end
    end

    it 'raises an error when contact is missing a phone number' do
      contact.update!(phone_number: nil)

      expect do
        described_class.perform!(
          account: account,
          inbox: inbox,
          user: user,
          contact: contact
        )
      end.to raise_error(ArgumentError, 'Contact phone number required')
    end

    it 'raises an error when user is nil' do
      expect do
        described_class.perform!(
          account: account,
          inbox: inbox,
          user: nil,
          contact: contact
        )
      end.to raise_error(ArgumentError, 'Agent required')
    end
  end
end
