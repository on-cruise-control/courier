require 'rails_helper'

describe SuperAdmin::DealerAgentPresenceService do
  let(:accounts) { [] }
  let(:service) { described_class.new(accounts: accounts) }

  describe '#perform' do
    it 'returns a hash with expected aggregation keys' do
      result = service.perform
      expect(result).to be_a(Hash)
      expect(result).to include(
        total_users: a_kind_of(Integer),
        total_active_user_sessions: a_kind_of(Integer),
        total_inactive_user_sessions: a_kind_of(Integer),
        total_users_by_account: a_kind_of(Hash),
        active_user_sessions_by_account: a_kind_of(Hash),
        inactive_user_sessions_by_account: a_kind_of(Hash),
        all_users: a_kind_of(Array)
      )
    end
  end
end
