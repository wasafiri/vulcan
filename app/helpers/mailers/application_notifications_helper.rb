module Mailers
  module ApplicationNotificationsHelper
    def format_proof_type(proof_type)
      proof_type.to_s.humanize.downcase
    end
  end
end
