require 'rails_helper'

RSpec.describe 'Offers API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:service) { instance_double(Offers::OfferService) }

  before do
    allow(Offers::OfferService).to receive(:new).with(account.dealership_id).and_return(service)
  end

  describe 'GET /api/v1/accounts/{account.id}/offers' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/offers"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when the service call succeeds' do
      it 'returns the list of offers' do
        allow(service).to receive(:fetch_offers).and_return({ results: [{ 'id' => 1 }] })

        get "/api/v1/accounts/#{account.id}/offers", headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['results']).to eq([{ 'id' => 1 }])
      end
    end

    context 'when the service call fails' do
      it 'renders the upstream error status instead of 200' do
        allow(service).to receive(:fetch_offers).and_return({ results: [], error: 'Dealership API server error', status: 502 })

        get "/api/v1/accounts/#{account.id}/offers", headers: admin.create_new_auth_token, as: :json

        expect(response).to have_http_status(502)
        expect(response.parsed_body['error']).to eq('Dealership API server error')
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/offers' do
    let(:valid_params) { { title: 'New Offer', start_date: '2026-01-01', end_date: '2026-01-31' } }

    context 'when the service call succeeds' do
      it 'returns the created offer' do
        allow(service).to receive(:create_offer).and_return({ 'id' => 1, 'title' => 'New Offer' })

        post "/api/v1/accounts/#{account.id}/offers", headers: admin.create_new_auth_token, params: valid_params, as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body['title']).to eq('New Offer')
      end
    end

    context 'when the upstream API rejects the request' do
      it 'does not report success and surfaces the real error status' do
        allow(service).to receive(:create_offer).and_return({ error: 'This field is required.', status: 400 })

        post "/api/v1/accounts/#{account.id}/offers", headers: admin.create_new_auth_token, params: valid_params, as: :json

        expect(response).to have_http_status(400)
        expect(response.parsed_body['error']).to eq('This field is required.')
      end
    end
  end

  describe 'PUT /api/v1/accounts/{account.id}/offers/:id' do
    it 'renders the upstream error status on failure' do
      allow(service).to receive(:update_offer).and_return({ error: 'Offer not found', status: 404 })

      put "/api/v1/accounts/#{account.id}/offers/1", headers: admin.create_new_auth_token, params: { title: 'Updated' }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['error']).to eq('Offer not found')
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/offers/:id' do
    it 'returns success when the service call succeeds' do
      allow(service).to receive(:delete_offer).and_return({ success: true })

      delete "/api/v1/accounts/#{account.id}/offers/1", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['success']).to be(true)
    end

    it 'renders the upstream error status on failure' do
      allow(service).to receive(:delete_offer).and_return({ error: 'Dealership API server error', status: 500 })

      delete "/api/v1/accounts/#{account.id}/offers/1", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:internal_server_error)
      expect(response.parsed_body['error']).to eq('Dealership API server error')
    end
  end
end
