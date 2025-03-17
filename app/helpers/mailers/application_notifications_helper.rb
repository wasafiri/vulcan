module Mailers
  module ApplicationNotificationsHelper
    def format_proof_type(proof_type)
      return '' if proof_type.nil?

      type_value = proof_type.respond_to?(:proof_type_before_type_cast) ? proof_type.proof_type_before_type_cast : proof_type

      case type_value.to_s
      when '0', 'income'
        'income'
      when '1', 'residency'
        'residency'
      else
        type_value.to_s
      end.humanize.downcase
    end
  end
end
