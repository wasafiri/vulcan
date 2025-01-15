class RemoveMedicalProviderFromApplications < ActiveRecord::Migration[8.0]
  def change
    remove_column :applications, :medical_provider_id, :integer, if_exists: true
  end
end
