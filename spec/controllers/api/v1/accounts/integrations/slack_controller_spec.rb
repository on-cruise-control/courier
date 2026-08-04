require 'rails_helper'

RSpec.describe 'Api::V1::Accounts::Integrations::SlackController', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'POST /api/v1/accounts/:account_id/integrations/slack' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/integrations/slack", as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated agent' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/integrations/slack",
             headers: agent.create_new_auth_token,
             as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated admin' do
      let(:slack_hook) { create(:integrations_hook, account: account, app_id: 'slack') }

      before do
        allow(Integrations::Slack::HookBuilder).to receive(:new).and_return(
          instance_double(Integrations::Slack::HookBuilder, perform: slack_hook)
        )
      end

      it 'creates the slack hook' do
        post "/api/v1/accounts/#{account.id}/integrations/slack",
             params: { code: 'test_code', inbox_id: create(:inbox, account: account).id },
             headers: admin.create_new_auth_token,
             as: :json
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'PATCH /api/v1/accounts/:account_id/integrations/slack' do
    context 'when it is an authenticated admin' do
      let!(:hook) { create(:integrations_hook, account: account, app_id: 'slack') }

      before do
        channel_builder = instance_double(Integrations::Slack::ChannelBuilder)
        allow(Integrations::Slack::ChannelBuilder).to receive(:new).with(hook: hook).and_return(channel_builder)
        allow(channel_builder).to receive(:update).with('new_channel_id').and_return(hook)
      end

      it 'updates the slack channel' do
        patch "/api/v1/accounts/#{account.id}/integrations/slack",
              params: { reference_id: 'new_channel_id' },
              headers: admin.create_new_auth_token,
              as: :json
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'DELETE /api/v1/accounts/:account_id/integrations/slack' do
    context 'when it is an authenticated admin' do
      let!(:hook) { create(:integrations_hook, account: account, app_id: 'slack') }

      it 'destroys the slack hook' do
        delete "/api/v1/accounts/#{account.id}/integrations/slack",
               headers: admin.create_new_auth_token,
               as: :json
        expect(response).to have_http_status(:success)
        expect(Integrations::Hook.exists?(hook.id)).to be false
      end
    end
  end

  describe 'GET /api/v1/accounts/:account_id/integrations/slack/list_all_channels' do
    context 'when it is an authenticated admin' do
      let!(:hook) { create(:integrations_hook, account: account, app_id: 'slack') }

      before do
        channel_builder = instance_double(Integrations::Slack::ChannelBuilder)
        allow(Integrations::Slack::ChannelBuilder).to receive(:new).with(hook: hook).and_return(channel_builder)
        allow(channel_builder).to receive(:fetch_channels).and_return([])
      end

      it 'returns list of channels' do
        get "/api/v1/accounts/#{account.id}/integrations/slack/list_all_channels",
            headers: admin.create_new_auth_token,
            as: :json
        expect(response).to have_http_status(:success)
      end
    end
  end
end
