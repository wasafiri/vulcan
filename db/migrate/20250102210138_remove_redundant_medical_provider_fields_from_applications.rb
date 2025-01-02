class RemoveRedundantMedicalProviderFieldsFromApplications < ActiveRecord::Migration[8.0]
  def change
    remove_column :applications, :medical_provider_name, :string
    remove_column :applications, :medical_provider_phone, :string
    remove_column :applications, :medical_provider_fax, :string
    remove_column :applications, :medical_provider_email, :string
  end
end
