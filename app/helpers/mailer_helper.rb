module MailerHelper
  # Get the color values for a status box
  # @param status [Symbol] The status (:success, :warning, :error, :info)
  # @return [Hash] The color values for the status
  def status_box_colors(status)
    colors = {
      success: {
        bg: "#ebf8ff",      # Light blue background
        border: "#90cdf4",  # Medium blue border
        text: "#2b6cb0",    # Dark blue text
        icon: "✓"           # Success icon
      },
      warning: {
        bg: "#fffaf0",      # Light orange background
        border: "#fbd38d",  # Medium orange border
        text: "#c05621",    # Dark orange text
        icon: "⚠"           # Warning icon
      },
      error: {
        bg: "#fff5f5",      # Light red background
        border: "#feb2b2",  # Medium red border
        text: "#c53030",    # Dark red text
        icon: "✗"           # Error icon
      },
      info: {
        bg: "#ebf4ff",      # Light blue background
        border: "#c3dafe",  # Medium blue border
        text: "#434190",    # Dark blue text
        icon: "ℹ"           # Info icon
      }
    }

    status = status.to_sym if status.respond_to?(:to_sym)
    colors[status] || colors[:info]
  end
  # Format a date consistently across all mailers
  # @param date [Date, Time, DateTime] The date to format
  # @param format [Symbol] The format to use (:short, :long, :full)
  # @return [String] The formatted date
  def format_date(date, format = :long)
    return "" if date.nil?

    case format
    when :short
      date.strftime("%m/%d/%Y")
    when :long
      date.strftime("%B %d, %Y")
    when :full
      date.strftime("%B %d, %Y at %I:%M %p")
    else
      date.strftime("%B %d, %Y")
    end
  end

  # Format a currency value consistently across all mailers
  # @param amount [Numeric] The amount to format
  # @param precision [Integer] The number of decimal places
  # @return [String] The formatted currency
  def format_currency(amount, precision = 2)
    number_to_currency(amount, precision: precision)
  end

  # Format a phone number consistently across all mailers
  # @param phone [String] The phone number to format
  # @return [String] The formatted phone number
  def format_phone(phone)
    return "" if phone.blank?

    # Remove all non-numeric characters
    digits = phone.to_s.gsub(/\D/, "")

    # Format based on length
    case digits.length
    when 10
      "(#{digits[0..2]}) #{digits[3..5]}-#{digits[6..9]}"
    when 11
      if digits[0] == "1"
        "+1 (#{digits[1..3]}) #{digits[4..6]}-#{digits[7..10]}"
      else
        digits
      end
    else
      phone # Return original if we can't format it
    end
  end

  # Format an address consistently across all mailers
  # @param address1 [String] Address line 1
  # @param address2 [String] Address line 2 (optional)
  # @param city [String] City
  # @param state [String] State
  # @param zip [String] ZIP code
  # @return [String] The formatted address
  def format_address(address1, address2, city, state, zip)
    address = address1.to_s
    address += "<br>#{address2}" if address2.present?
    address += "<br>#{city}, #{state} #{zip}"
    address.html_safe
  end

  # Format an address for plain text emails
  # @param address1 [String] Address line 1
  # @param address2 [String] Address line 2 (optional)
  # @param city [String] City
  # @param state [String] State
  # @param zip [String] ZIP code
  # @return [String] The formatted address
  def format_text_address(address1, address2, city, state, zip)
    address = address1.to_s
    address += "\n#{address2}" if address2.present?
    address += "\n#{city}, #{state} #{zip}"
    address
  end

  # Format a proof type consistently across all mailers
  # @param proof_type [String, Symbol, Integer] The proof type
  # @return [String] The formatted proof type
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
