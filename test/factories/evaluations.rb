# frozen_string_literal: true

# test/factories/evaluations.rb
FactoryBot.define do
  factory :evaluation do
    association :evaluator, type: 'Users::Evaluator'
    constituent
    application
    evaluation_date { Time.current }
    evaluation_type { :initial }
    status { :requested }
    notes { 'Default evaluation notes' }
    report_submitted { false }
    location { 'Main Office' }
    needs { 'Additional support for mobility.' }

    # Default attendees
    attendees do
      [
        { 'name' => 'John Doe', 'relationship' => 'Self' },
        { 'name' => 'Jane Smith', 'relationship' => 'Caregiver' }
      ]
    end

    # Set up default products
    after(:build) do |evaluation|
      # Create products directly
      ipad_air = create(:product, name: 'iPad Air')
      ipad_mini = create(:product, name: 'iPad Mini')

      # Set up products tried
      evaluation.products_tried = [
        { 'product_id' => ipad_air.id, 'reaction' => 'Satisfied' },
        { 'product_id' => ipad_mini.id, 'reaction' => 'Neutral' }
      ]

      # Set recommended products
      evaluation.recommended_product_ids = [ipad_air.id, ipad_mini.id]
    end

    trait :completed do
      status { :completed }
      notes { 'Evaluation completed successfully.' }
      report_submitted { true }
      submitted_at { Time.current }
    end

    trait :pending do
      status { :scheduled }
      notes { 'Pending evaluation notes' }
    end

    trait :with_custom_attendees do
      attendees do
        [
          { 'name' => 'Alice Johnson', 'relationship' => 'Self' }
        ]
      end
    end

    trait :with_mobile_devices do
      after(:build) do |evaluation|
        iphone = create(:product, name: 'iPhone')
        pixel = create(:product, name: 'Pixel')

        evaluation.products_tried = [
          { 'product_id' => iphone.id, 'reaction' => 'Very Satisfied' },
          { 'product_id' => pixel.id, 'reaction' => 'Satisfied' }
        ]
        evaluation.recommended_product_ids = [iphone.id, pixel.id]
      end
    end

    trait :with_single_product do
      after(:build) do |evaluation|
        ipad = create(:product, name: 'iPad Air')
        evaluation.products_tried = [
          { 'product_id' => ipad.id, 'reaction' => 'Very Satisfied' }
        ]
        evaluation.recommended_product_ids = [ipad.id]
      end
    end
  end
end
