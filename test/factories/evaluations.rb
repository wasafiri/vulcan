# frozen_string_literal: true

# test/factories/evaluations.rb
FactoryBot.define do
  factory :evaluation do
    evaluator
    constituent
    application
    evaluation_date { Time.current }
    evaluation_type { :initial }
    status { :pending }
    notes { 'Default evaluation notes' } # Default notes to avoid validation error
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

    # Set up default products using fixtures
    after(:build) do |evaluation|
      # Get our known iPad fixtures
      ipad_air = Product.find_by(name: 'iPad Air') || products(:ipad_air)
      ipad_mini = Product.find_by(name: 'iPad Mini') || products(:ipad_mini)

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
    end

    trait :pending do
      status { :pending }
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
        iphone = Product.find_by(name: 'iPhone') || products(:iphone)
        pixel = Product.find_by(name: 'Pixel') || products(:pixel)

        evaluation.products_tried = [
          { 'product_id' => iphone.id, 'reaction' => 'Very Satisfied' },
          { 'product_id' => pixel.id, 'reaction' => 'Satisfied' }
        ]
        evaluation.recommended_product_ids = [iphone.id, pixel.id]
      end
    end

    trait :with_single_product do
      after(:build) do |evaluation|
        ipad = Product.find_by(name: 'iPad Air') || products(:ipad_air)
        evaluation.products_tried = [
          { 'product_id' => ipad.id, 'reaction' => 'Very Satisfied' }
        ]
        evaluation.recommended_product_ids = [ipad.id]
      end
    end
  end
end
