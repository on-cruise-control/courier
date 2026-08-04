require 'rails_helper'

describe UserDailySessions::FinalizeService do
  let(:account) { create(:account) }
  let(:user) { create(:user) }
  let(:account_user) { create(:account_user, account: account, user: user) }
  let(:timestamp) { Time.current }
  let(:service) { described_class.new(account_user: account_user, timestamp: timestamp) }

  describe '#perform' do
    context 'when a session exists with a start time' do
      let!(:session) do
        create(
          :user_daily_session,
          account_id: account.id,
          user_id: user.id,
          session_started_at: timestamp - 5.minutes,
          duration_seconds: 120
        )
      end

      it 'finalizes the session and updates duration' do
        result = service.perform
        expect(result).to eq(session)
        session.reload
        expect(session.session_started_at).to be_nil
        # duration increased by 5 minutes (300 seconds) plus existing 120
        expect(session.duration_seconds).to eq(420)
      end
    end

    context 'when no session exists' do
      it 'returns nil' do
        expect(service.perform).to be_nil
      end
    end
  end
end
