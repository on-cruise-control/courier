FactoryBot.define do
  factory :account_twilio_configuration do
    account
    account_sid { SecureRandom.uuid }
    auth_token { SecureRandom.uuid }
    phone_number { '+1098765432' }
  end
end
