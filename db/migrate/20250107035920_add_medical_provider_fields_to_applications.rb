class AddMedicalProviderFieldsToApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :applications, :medical_provider_name, :string
    add_column :applications, :medical_provider_phone, :string
    add_column :applications, :medical_provider_fax, :string
    add_column :applications, :medical_provider_email, :string
  end
end
