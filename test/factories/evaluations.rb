FactoryBot.define do
  factory :evaluation do
    evaluator
    constituent
    application
    evaluation_date { Time.current }
    evaluation_type { :initial }
    status { :pending }
    notes { "" }
    report_submitted { false }

    # Required Fields
    location { "Main Office" }
    needs { "Additional support for mobility." }

    # Attendees: Array of hashes with "name" and "relationship"
    attendees { [
      { "name" => "John Doe", "relationship" => "Self" },
      { "name" => "Jane Smith", "relationship" => "Caregiver" }
    ] }

    # Products Tried: Array of hashes with "product_id" and "reaction"
    products_tried { [
      { "product_id" => Product.all.sample.id, "reaction" => "Satisfied" },
      { "product_id" => Product.all.sample.id, "reaction" => "Neutral" }
    ] }

    # Recommended Products: Association
    before(:create) do |evaluation|
      # Ensure there are at least two products available
      if Product.count < 2
        raise "Not enough products available to associate with Evaluation."
      end
      # Assign two random products as recommended_products
      recommended = Product.order("RANDOM()").limit(2)
      evaluation.recommended_products << recommended
    end

    # Traits for different statuses
    trait :completed do
      status { :completed }
      notes { "Evaluation completed successfully." }
      report_submitted { true }
    end

    trait :with_custom_attendees do
      attendees { [
        { "name" => "Alice Johnson", "relationship" => "Self" }
      ] }
    end

    trait :with_custom_products_tried do
      products_tried { [
        { "product_id" => Product.all.sample.id, "reaction" => "Very Satisfied" }
      ] }
    end
  end
end
