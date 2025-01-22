class AddMedicalCertificationStatusToApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :applications, :medical_certification_status, :integer, default: 0, null: false
    add_index :applications, :medical_certification_status
  end
end
