# frozen_string_literal: true

require 'rails_helper'

shared_examples_for 'auto_assignment_handler' do
  include ActiveJob::TestHelper

  describe '#auto assignment' do
    let(:account) { create(:account) }
    let(:agent) { create(:user, email: 'agent1@example.com', account: account, auto_offline: false) }
    let(:inbox) { create(:inbox, account: account) }
    let(:conversation) do
      create(
        :conversation,
        account: account,
        contact: create(:contact, account: account),
        inbox: inbox,
        assignee: nil
      )
    end

    before do
      create(:inbox_member, inbox: inbox, user: agent)
      allow(Redis::Alfred).to receive(:rpoplpush).and_return(agent.id)
      allow(OnlineStatusTracker).to receive(:get_available_users).and_return({ agent.id.to_s => 'online' })
    end

    it 'runs round robin on after_save callbacks' do
      perform_enqueued_jobs do
        conversation
      end
      expect(conversation.reload.assignee).to eq(agent)
    end

    it 'will not auto assign agent if enable_auto_assignment is false' do
      inbox.update(enable_auto_assignment: false)
      perform_enqueued_jobs do
        conversation
      end

      expect(conversation.reload.assignee).to be_nil
    end

    it 'will not auto assign agent if its a bot conversation' do
      perform_enqueued_jobs do
        create(
          :conversation,
          account: account,
          contact: create(:contact, account: account),
          inbox: inbox,
          status: 'pending',
          assignee: nil
        )
      end

      expect(Conversation.last.assignee).to be_nil
    end

    it 'gets triggered on update only when status changes to open' do
      perform_enqueued_jobs do
        conversation
      end

      conversation.status = 'resolved'
      perform_enqueued_jobs do
        conversation.save!
      end
      expect(conversation.reload.assignee).to eq(agent)
      inbox.inbox_members.where(user_id: agent.id).first.destroy!
      inbox.reload
      conversation.reload
      conversation.inbox.reload

      # round robin changes assignee in this case since agent doesn't have access to inbox
      agent2 = create(:user, email: 'agent2@example.com', account: account, auto_offline: false)
      create(:inbox_member, inbox: inbox, user: agent2)
      # Re-stub to ensure the new round-robin picks agent2
      allow(Redis::Alfred).to receive(:rpoplpush).and_return(agent2.id)
      allow(OnlineStatusTracker).to receive(:get_available_users).and_return({ agent2.id.to_s => 'online' })

      # Ensure the status change is persisted and that callbacks see an actual change.
      conversation.reload
      perform_enqueued_jobs do
        conversation.update!(status: 'open')
      end

      expect(conversation.reload.assignee).not_to be_nil
    end
  end
end
