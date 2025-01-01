class MakeMedicalProviderOptionalInApplications < ActiveRecord::Migration[8.0]
  def change
    change_column_null :applications, :medical_provider_id, true
  end
end
