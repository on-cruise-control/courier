require 'rails_helper'

describe UserDailySessions::RecordActivityService do
  let(:account) { create(:account) }
  let(:user) { create(:user) }
  let(:account_user) { create(:account_user, account: account, user: user) }
  let(:timestamp) { Time.current }
  let(:service) { described_class.new(account_user: account_user, timestamp: timestamp) }

  describe '#perform' do
    context 'when there is no existing session for the day' do
      it 'creates a new session and updates active_at' do
        result = service.perform
        expect(result).to be_a(UserDailySession)
        expect(result.session_started_at).to be_within(1.second).of(timestamp)
        expect(result.session_date).to eq(timestamp.to_date)
        account_user.reload
        expect(account_user.active_at).to be_within(1.second).of(timestamp)
      end
    end

    context 'when a session already exists and is stale' do
      let!(:existing_session) do
        create(
          :user_daily_session,
          account_id: account.id,
          user_id: user.id,
          session_started_at: timestamp - 2.hours,
          duration_seconds: 60,
          session_date: timestamp.to_date
        )
      end

      before do
        # Simulate stale session by setting active_at far in the past
        account_user.update!(active_at: timestamp - 2.hours)
      end

      it 'finalizes the old session and starts a new one' do
        result = service.perform
        expect(result).to be_a(UserDailySession)
        # Old session should have been finalized
        existing_session.reload
        expect(existing_session.duration_seconds).to be > 60
        # New session started_at should be current timestamp
        expect(result.session_started_at).to be_within(1.second).of(timestamp)
        expect(result.session_date).to eq(timestamp.to_date)
        account_user.reload
        expect(account_user.active_at).to be_within(1.second).of(timestamp)
      end
    end

    context 'when a session exists and is still active' do
      let!(:active_session) do
        create(
          :user_daily_session,
          account_id: account.id,
          user_id: user.id,
          session_started_at: timestamp - 5.minutes,
          duration_seconds: 120,
          session_date: timestamp.to_date
        )
      end

      before do
        account_user.update!(active_at: timestamp)
      end

      it 'does not finalize the session and keeps the same record' do
        result = service.perform
        expect(result.id).to eq(active_session.id)
        expect(result.session_started_at).to eq(active_session.session_started_at)
        expect(result.duration_seconds).to eq(active_session.duration_seconds)
        account_user.reload
        expect(account_user.active_at).to be_within(1.second).of(timestamp)
      end
    end
  end
end
