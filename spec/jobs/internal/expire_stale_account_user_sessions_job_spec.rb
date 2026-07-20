require 'rails_helper'

RSpec.describe Internal::ExpireStaleAccountUserSessionsJob do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:account_user) { AccountUser.find_by(account: account, user: user) }
  let(:finalize_service) { instance_double(UserDailySessions::FinalizeService) }

  describe '#perform' do
    context 'when account_user has a stale active_at' do
      before do
        account_user.update!(active_at: AccountUser::SESSION_ACTIVE_TIMEOUT.ago - 1.hour)
        allow(OnlineStatusTracker).to receive(:get_presence).and_return(false)
        allow(UserDailySessions::FinalizeService).to receive(:new).with(account_user: account_user).and_return(finalize_service)
        allow(finalize_service).to receive(:perform)
      end

      it 'calls UserDailySessions::FinalizeService for the stale account_user' do
        described_class.perform_now
        expect(UserDailySessions::FinalizeService).to have_received(:new).with(account_user: account_user)
        expect(finalize_service).to have_received(:perform)
      end
    end

    context 'when account_user is online' do
      before do
        allow(OnlineStatusTracker).to receive(:get_presence).and_return(true)
        allow(UserDailySessions::FinalizeService).to receive(:new)
      end

      it 'does not finalize the session' do
        described_class.perform_now
        expect(UserDailySessions::FinalizeService).not_to have_received(:new)
      end
    end

    context 'when account_user has a recent active_at' do
      before do
        account_user.update!(active_at: 1.minute.ago)
        allow(OnlineStatusTracker).to receive(:get_presence).and_return(false)
        allow(UserDailySessions::FinalizeService).to receive(:new)
      end

      it 'does not finalize the session' do
        described_class.perform_now
        expect(UserDailySessions::FinalizeService).not_to have_received(:new)
      end
    end
  end
end
