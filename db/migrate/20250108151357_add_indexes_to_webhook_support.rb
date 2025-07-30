# db/migrate/20250108151357_add_indexes_to_webhook_support.rb
class AddIndexesToWebhookSupport < ActiveRecord::Migration[8.0]
  def change
    # Add indexes to the applications table
    add_index :applications, %i[medical_provider_email status], name: "index_applications_on_medical_provider_email_and_status"

    # Add index to 'bounced_at' if it exists in the applications table
    add_index :applications, :bounced_at, name: "index_applications_on_bounced_at" if column_exists?(:applications, :bounced_at)

    if table_exists?(:proof_submission_audits)
      add_index :proof_submission_audits, %i[application_id created_at], name: "index_proof_submission_audits_on_application_id_and_created_at"
    end
  end
end
