class AddAlternateContactFieldsToApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :applications, :alternate_contact_name, :string
    add_column :applications, :alternate_contact_phone, :string
    add_column :applications, :alternate_contact_email, :string
  end
end
