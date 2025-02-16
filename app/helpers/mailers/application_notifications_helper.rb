module Mailers
  module ApplicationNotificationsHelper
    def format_proof_type(proof_type)
      return "" if proof_type.nil?

      # If it's a ProofReview instance, get the proof_type before type cast
      if proof_type.respond_to?(:proof_type_before_type_cast)
        type_value = proof_type.proof_type_before_type_cast
      else
        type_value = proof_type
      end

      # Convert to string and handle both symbol and integer cases
      case type_value.to_s
      when "0", "income"
        "income"
      when "1", "residency"
        "residency"
      else
        type_value.to_s
      end.humanize.downcase
    end
  end
end
