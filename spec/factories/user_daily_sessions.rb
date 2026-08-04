FactoryBot.define do
  factory :user_daily_session do
    association :account
    association :user
    session_date { Date.current }
    session_started_at { Time.current }
    duration_seconds { 0 }
    # other optional fields can be left nil
  end
end
