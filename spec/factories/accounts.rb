# frozen_string_literal: true

FactoryBot.define do
  factory :account do
    sequence(:name) { |n| "Account #{n}" }
    sequence(:dealership_id) { SecureRandom.uuid }
    status { 'active' }
    domain { 'test.com' }
    support_email { 'support@test.com' }

    after(:build) do |account|
      account.extend(Enterprise::Account) if defined?(Enterprise::Account)
    end
  end
end
