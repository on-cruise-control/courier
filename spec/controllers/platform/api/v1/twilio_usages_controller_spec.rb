require 'rails_helper'

RSpec.describe 'Platform Twilio Usages API', type: :request do
  let(:account) { create(:account, dealership_id: 'dealership-123') }
  let(:platform_app) { create(:platform_app) }

  before do
    create(:platform_app_permissible, platform_app: platform_app, permissible: account)
  end

  describe 'GET /platform/api/v1/dealership/:dealership_id/twilio_usage' do
    context 'when it is an unauthenticated platform app' do
      it 'returns unauthorized' do
        get "/platform/api/v1/dealership/#{account.dealership_id}/twilio_usage"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when dealership does not exist' do
      it 'returns not found' do
        get '/platform/api/v1/dealership/nonexistent/twilio_usage',
            headers: { api_access_token: platform_app.access_token.token },
            as: :json
        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body['error']).to eq('Dealership not found')
      end
    end

    context 'when it is an authenticated platform app' do
      before do
        usage_service = instance_double(Twilio::UsageService)
        allow(Twilio::UsageService).to receive(:new).with(account).and_return(usage_service)
        allow(usage_service).to receive(:usage).with(api_version: 'v1').and_return({ success: true, total_usage: { price: 0.0 } })
      end

      it 'returns the twilio usage' do
        get "/platform/api/v1/dealership/#{account.dealership_id}/twilio_usage",
            headers: { api_access_token: platform_app.access_token.token },
            as: :json
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['success']).to be true
      end
    end
  end
end
