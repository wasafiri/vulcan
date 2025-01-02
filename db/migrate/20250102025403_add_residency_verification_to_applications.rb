class AddResidencyVerificationToApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :applications, :maryland_resident, :boolean
    add_column :applications, :draft, :boolean, default: true
    add_column :applications, :terms_accepted, :boolean
    add_column :applications, :information_verified, :boolean
    add_column :applications, :medical_release_authorized, :boolean
  end
end
