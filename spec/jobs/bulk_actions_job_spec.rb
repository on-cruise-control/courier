require 'rails_helper'

RSpec.describe BulkActionsJob do
  subject(:job) { described_class.perform_later(account: account, params: params, user: agent) }

  let(:account) { create(:account) }
  let!(:agent) { create(:user, account: account, role: :agent) }
  let!(:conversation_1) { create(:conversation, account_id: account.id, status: :open) }
  let!(:conversation_2) { create(:conversation, account_id: account.id, status: :open) }
  let!(:conversation_3) { create(:conversation, account_id: account.id, status: :open) }
  let(:conversation_ids) { [conversation_1.display_id, conversation_2.display_id, conversation_3.display_id] }
  let(:params) { { type: 'Conversation', fields: { status: 'snoozed' }, ids: conversation_ids } }

  before do
    [conversation_1, conversation_2, conversation_3].each do |conversation|
      create(:inbox_member, inbox: conversation.inbox, user: agent)
    end
  end

  it 'enqueues the job' do
    expect { job }.to have_enqueued_job(described_class)
      .with(account: account, params: params, user: agent)
      .on_queue('medium')
  end

  context 'when job is triggered' do
    let(:bulk_action_job) { double }

    before do
      allow(bulk_action_job).to receive(:perform)
    end

    it 'bulk updates the status' do
      params = {
        type: 'Conversation',
        fields: { status: 'snoozed', assignee_id: agent.id },
        ids: conversation_ids
      }

      expect(conversation_1.status).to eq('open')

      described_class.perform_now(account: account, params: params, user: agent)

      expect(conversation_1.reload.status).to eq('snoozed')
      expect(conversation_2.reload.status).to eq('snoozed')
      expect(conversation_3.reload.status).to eq('snoozed')
    end

    it 'bulk updates the assignee_id' do
      params = {
        type: 'Conversation',
        fields: { status: 'snoozed', assignee_id: agent.id },
        ids: conversation_ids
      }

      expect(conversation_1.assignee_id).to be_nil

      described_class.perform_now(account: account, params: params, user: agent)

      expect(conversation_1.reload.assignee_id).to eq(agent.id)
      expect(conversation_2.reload.assignee_id).to eq(agent.id)
      expect(conversation_3.reload.assignee_id).to eq(agent.id)
    end

    it 'bulk updates the snoozed_until' do
      params = {
        type: 'Conversation',
        fields: { status: 'snoozed', snoozed_until: Time.zone.now },
        ids: conversation_ids
      }

      expect(conversation_1.snoozed_until).to be_nil

      described_class.perform_now(account: account, params: params, user: agent)

      expect(conversation_1.reload.snoozed_until).to be_present
      expect(conversation_2.reload.snoozed_until).to be_present
      expect(conversation_3.reload.snoozed_until).to be_present
    end

    it 'updates conversations regardless of inbox membership' do
      other_conversation = create(:conversation, account_id: account.id, status: :open)
      params = {
        type: 'Conversation',
        fields: { status: 'resolved' },
        ids: [conversation_1.display_id, other_conversation.display_id]
      }

      described_class.perform_now(account: account, params: params, user: agent)

      expect(conversation_1.reload.status).to eq('resolved')
      expect(other_conversation.reload.status).to eq('resolved')
    end

    it 'bulk updates is_blacklisted' do
      params = {
        type: 'Conversation',
        fields: { is_blacklisted: true },
        ids: conversation_ids
      }

      described_class.perform_now(account: account, params: params, user: agent)

      expect(conversation_1.reload.is_blacklisted).to be true
      expect(conversation_2.reload.is_blacklisted).to be true
      expect(conversation_3.reload.is_blacklisted).to be true
    end

    context 'when a conversation with a scheduled follow-up job is newly blacklisted' do
      it 'cancels the existing follow-up job' do
        conversation_1.update!(follow_up_jid: 'some_jid')
        scheduled_job = instance_double(Sidekiq::SortedEntry)
        scheduled_set = instance_double(Sidekiq::ScheduledSet)
        allow(Sidekiq::ScheduledSet).to receive(:new).and_return(scheduled_set)
        allow(scheduled_set).to receive(:find_job).with('some_jid').and_return(scheduled_job)
        allow(scheduled_job).to receive(:delete)

        params = { type: 'Conversation', fields: { is_blacklisted: true }, ids: [conversation_1.display_id] }
        described_class.perform_now(account: account, params: params, user: agent)

        expect(scheduled_job).to have_received(:delete)
        expect(conversation_1.reload.follow_up_jid).to be_nil
      end
    end

    context 'when a conversation is already blacklisted' do
      it 'does not attempt to cancel a follow-up job again' do
        conversation_1.update!(is_blacklisted: true, follow_up_jid: 'some_jid')
        params = { type: 'Conversation', fields: { is_blacklisted: true }, ids: [conversation_1.display_id] }

        expect(Sidekiq::ScheduledSet).not_to receive(:new)

        described_class.perform_now(account: account, params: params, user: agent)
      end
    end
  end
end
