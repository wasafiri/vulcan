# frozen_string_literal: true

class RemoveDefaultFromSelfCertifyDisabilityInApplications < ActiveRecord::Migration[8.0]
  def change
    # Remove the default value (false) from the self_certify_disability column
    # Setting the new default to nil effectively removes it
    change_column_default :applications, :self_certify_disability, from: false, to: nil
  end
end
