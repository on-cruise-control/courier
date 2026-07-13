require 'rails_helper'

RSpec.describe 'Platform Contacts API', type: :request do
  let(:account) { create(:account) }
  let(:contact) { create(:contact, account: account) }
  let(:platform_app) { create(:platform_app) }

  before do
    create(:platform_app_permissible, platform_app: platform_app, permissible: account)
  end

  # Platform::Api::V1::ContactsController and its route are still in progress
  # and not part of this push yet.
  describe 'GET /platform/api/v1/contacts/:id' do
    context 'when it is an unauthenticated platform app' do
      xit 'returns unauthorized' do
        get "/platform/api/v1/contacts/#{contact.id}"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated platform app' do
      xit 'returns the contact' do
        get "/platform/api/v1/contacts/#{contact.id}",
            headers: { api_access_token: platform_app.access_token.token },
            as: :json
        expect(response).to have_http_status(:success)
        expect(response.parsed_body['id']).to eq(contact.id)
      end
    end
  end

  describe 'PATCH /platform/api/v1/contacts/:id' do
    context 'when it is an authenticated platform app' do
      # date_of_birth support for the platform API is still in progress and not
      # part of this push yet.
      xit 'updates the contact date_of_birth' do
        patch "/platform/api/v1/contacts/#{contact.id}",
              params: { date_of_birth: '1990-01-01' },
              headers: { api_access_token: platform_app.access_token.token },
              as: :json
        expect(response).to have_http_status(:success)
        expect(response.parsed_body['date_of_birth']).to eq('1990-01-01')
      end
    end
  end
end
