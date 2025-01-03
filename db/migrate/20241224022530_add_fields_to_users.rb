class AddFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    change_table :users do |t|
      ## STI Column
      t.string :type, index: true

      ## personal Information
      t.string :first_name
      t.string :middle_initial
      t.string :last_name
      t.string :phone
      t.date :date_of_birth
      t.string :ssn_last4

      ## address Information
      t.string :physical_address_1
      t.string :physical_address_2
      t.string :city
      t.string :state
      t.string :zip_code
      t.string :county_of_residence

      ## authentication and security
      t.datetime :last_sign_in_at
      t.string :last_sign_in_ip
      t.integer :failed_attempts
      t.datetime :locked_at

      ## status and preferences
      t.integer :status
      t.boolean :valid_dcf, default: false
      t.boolean :previous_application_submitted, default: false
      t.boolean :newsletter_signup, default: false
      t.boolean :home_internet_service, default: false
      t.json :availability_schedule
      t.integer :communication_preference
      t.string :timezone
      t.string :locale
      t.string :preferred_means_of_communication

      ## disabilities
      t.boolean :hearing_disability, default: false
      t.boolean :vision_disability, default: false
      t.boolean :speech_disability, default: false
      t.boolean :mobility_disability, default: false
      t.boolean :cognition_disability, default: false

      ## verification of eligibility
      t.string :income_proof
      t.string :residency_proof

      ## references (Foreign Keys)
      t.references :income_verified_by, foreign_key: { to_table: :users }
      t.references :evaluator, foreign_key: { to_table: :users }
      t.references :recipient, foreign_key: { to_table: :users }
      t.references :medical_provider, foreign_key: { to_table: :users }
    end
  end
end
