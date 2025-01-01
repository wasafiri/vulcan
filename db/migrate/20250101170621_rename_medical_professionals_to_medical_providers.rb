class RenameMedicalProfessionalsToMedicalProviders < ActiveRecord::Migration[8.0]
  def change
    rename_table :medical_professionals, :medical_providers
  end
end
