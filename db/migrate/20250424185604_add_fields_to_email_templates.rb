class AddFieldsToEmailTemplates < ActiveRecord::Migration[8.0]
  def change
    # Add new columns, allowing NULL initially
    add_column :email_templates, :format, :integer, default: 0, null: true # Assuming 0 = :html
    add_column :email_templates, :description, :text, null: true
    add_column :email_templates, :version, :integer, default: 1, null: true
    add_column :email_templates, :previous_subject, :string, null: true
    add_column :email_templates, :previous_body, :text, null: true

    # Add index for version separately if needed, though maybe not necessary unless querying by version often
    # add_index :email_templates, :version

    # Optional: Backfill existing records if necessary (might be better in a data migration or seed task)
    # EmailTemplate.update_all(format: 0, version: 1)

    # Optional: Change columns to NOT NULL after backfilling/seeding if desired
    # change_column_null :email_templates, :format, false
    # change_column_null :email_templates, :version, false
  end
end
