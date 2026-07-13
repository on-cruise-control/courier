require 'rails_helper'

RSpec.describe 'Webhooks::FacebookController', type: :request do
  before do
    allow(Facebook::Messenger::Subscriptions).to receive(:subscribe).and_return(true)
  end

  describe 'GET /webhooks/facebook' do
    it 'returns ok when valid params are not present' do
      get '/webhooks/facebook'
      expect(response).to have_http_status(:ok)
    end

    it 'returns challenge when valid params' do
      with_modified_env FB_VERIFY_TOKEN: '123456' do
        get '/webhooks/facebook', params: { 'hub.challenge' => '123456', 'hub.mode' => 'subscribe', 'hub.verify_token' => '123456' }
        expect(response.body).to include '123456'
      end
    end
  end

  describe 'POST /webhooks/facebook' do
    let(:page) { create(:channel_facebook_page) }
    let(:contact_inbox) { create(:contact_inbox, inbox: page.inbox) }

    before do
      allow(Channel::FacebookPage).to receive(:find_by).and_return(page)
      allow(page).to receive(:inbox).and_return(page.inbox)
      allow(ContactInboxWithContactBuilder).to receive(:new).and_return(
        instance_double(ContactInboxWithContactBuilder, perform: contact_inbox)
      )
      allow(SendCommentReplyJob).to receive(:set).and_return(instance_double(ActiveJob::ConfiguredJob, perform_later: true))
      allow(SendTemplateDmJob).to receive(:set).and_return(instance_double(ActiveJob::ConfiguredJob, perform_later: true))
    end

    it 'returns ok for valid payload' do
      payload = {
        'entry' => [
          {
            'id' => 'page_123',
            'changes' => [
              {
                'value' => {
                  'item' => 'comment',
                  'verb' => 'add',
                  'comment_id' => 'comment_123',
                  'from' => { 'id' => 'user_123', 'name' => 'Test User' },
                  'message' => 'Hello',
                  'post' => { 'permalink_url' => 'http://example.com/post' }
                }
              }
            ]
          }
        ]
      }

      post '/webhooks/facebook',
           params: payload.to_json,
           headers: { 'CONTENT_TYPE' => 'application/json' }
      expect(response).to have_http_status(:ok)
    end
  end
end
