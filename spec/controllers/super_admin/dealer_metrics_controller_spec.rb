require 'rails_helper'

RSpec.describe 'Super Admin Dealer Metrics API', type: :request do
  let(:super_admin) { create(:super_admin) }
  let(:account) { create(:account, dealership_id: 'dealership-123') }

  describe 'GET /super_admin/dealer_metrics' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get '/super_admin/dealer_metrics'
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when it is an authenticated super admin' do
      before do
        service = instance_double(SuperAdmin::DealerMetricsService)
        allow(SuperAdmin::DealerMetricsService).to receive(:new).and_return(service)
        allow(service).to receive(:perform).at_least(:once).and_return({ filters: {}, sections: [] })
      end

      it 'returns JSON when format is json' do
        sign_in(super_admin, scope: :super_admin)
        get '/super_admin/dealer_metrics', params: { page: 'conversations' }, as: :json
        expect(response).to have_http_status(:success)
      end
    end
  end
end
