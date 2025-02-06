class AddMedicalCertificationFields < ActiveRecord::Migration[8.0]
  def change
    add_column :applications, :medical_certification_verified_at, :datetime
    add_column :applications, :medical_certification_verified_by_id, :bigint
    add_column :applications, :medical_certification_rejection_reason, :text

    add_index :applications, :medical_certification_verified_by_id
    add_foreign_key :applications, :users, column: :medical_certification_verified_by_id
  end
end
