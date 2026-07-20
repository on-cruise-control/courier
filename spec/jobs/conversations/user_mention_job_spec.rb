require 'rails_helper'

RSpec.describe Conversations::UserMentionJob do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:conversation) { create(:conversation, account: account) }

  describe '#perform' do
    context 'when mention does not already exist' do
      it 'creates a new mention for each user_id' do
        expect do
          described_class.perform_now([user.id], conversation.id, account.id)
        end.to change(Mention, :count).by(1)

        mention = Mention.last
        expect(mention.user_id).to eq(user.id)
        expect(mention.conversation_id).to eq(conversation.id)
        expect(mention.account_id).to eq(account.id)
      end
    end

    context 'when mention already exists' do
      let!(:existing_mention) do
        Mention.create!(
          user_id: user.id,
          conversation_id: conversation.id,
          account_id: account.id,
          mentioned_at: 1.day.ago
        )
      end

      it 'updates the mentioned_at timestamp' do
        expect do
          described_class.perform_now([user.id], conversation.id, account.id)
        end.not_to change(Mention, :count)

        expect(existing_mention.reload.mentioned_at).to be_within(1.second).of(Time.zone.now)
      end
    end
  end
end
