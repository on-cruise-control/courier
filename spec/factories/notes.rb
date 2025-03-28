# frozen_string_literal: true

FactoryBot.define do
  factory :note do
    content { 'Hey welcome to cruise control' }
    account
    user
    contact
  end
end
