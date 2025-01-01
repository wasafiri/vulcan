class AddDisabilityCertificationToApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :applications, :self_certify_disability, :boolean, default: false
  end
end
