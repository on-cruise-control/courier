# frozen_string_literal: true

FactoryBot.define do
  factory :channel_instagram_fb_page, class: 'Channel::Instagram' do
    expires_at { 1.day.from_now }
    access_token { SecureRandom.uuid }
    instagram_id { SecureRandom.uuid }
    instagram_profile_url { 'https://instagram.com/profile' }
    account

    after(:build) do |channel|
      def channel.access_token
        'test_token'
      end
    end
  end
end
