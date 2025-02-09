class AddMedicalCertificationTrackingToApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :applications, :medical_certification_requested_at, :datetime
    add_column :applications, :medical_certification_request_count, :integer, default: 0
  end
end
