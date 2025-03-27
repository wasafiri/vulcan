# frozen_string_literal: true

FactoryBot.define do
  factory :application_note do
    association :application
    association :admin, factory: :user, type: 'Admin'
    content { 'This is a note about the application.' }
    internal_only { true }

    trait :public do
      content { 'This is a public note visible to the constituent.' }
      internal_only { false }
    end

    trait :internal do
      content { 'This is an internal note only visible to admins.' }
      internal_only { true }
    end
  end
end
