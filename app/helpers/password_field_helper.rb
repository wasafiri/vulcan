module PasswordFieldHelper
  # Creates a password field with a visibility toggle button using Rails form helpers
  #
  # @param form [FormBuilder] The form builder object
  # @param field_name [Symbol] The name of the password field
  # @param options [Hash] Options for customizing the password field
  # @option options [String] :label Custom label text
  # @option options [String] :placeholder Placeholder text
  # @option options [Boolean] :required Whether the field is required
  # @option options [String] :autocomplete Autocomplete attribute value
  # @option options [Integer] :timeout Timeout in milliseconds before hiding password again
  # @option options [String] :hint Hint text to display below the field
  # @option options [Hash] :html_options Additional HTML options for the password field
  #
  # @return [String] HTML for the password field with visibility toggle
  def password_field_with_toggle(form, field_name, options = {})
    # Extract options with defaults
    label = options.delete(:label) || field_name.to_s.humanize
    placeholder = options.delete(:placeholder)
    required = options.delete(:required) != false
    autocomplete = options.delete(:autocomplete) || (field_name.to_s.include?("confirmation") ? "new-password" : "current-password")
    timeout = options.delete(:timeout) || 5000
    hint = options.delete(:hint)
    html_options = options.delete(:html_options) || {}

    # Generate IDs and status ID
    field_id = options[:id] || "#{form.object_name}_#{field_name}"
    status_id = "#{field_id}_visibility_status"

    # Build HTML classes - increase right padding to prevent overlap with browser suggestions
    base_classes = "mt-1 block w-full px-4 py-2 pr-12 bg-white border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
    classes = html_options[:class] ? "#{base_classes} #{html_options[:class]}" : base_classes

    # Add minlength if it's a password field and not already specified
    html_options[:minlength] = 6 if field_name.to_s.include?("password") && !html_options.key?(:minlength)

    # Prepare field options
    field_options = {
      class: classes,
      required: required,
      autocomplete: autocomplete,
      data: {
        visibility_target: field_name.to_s.include?("confirmation") ? "fieldConfirmation" : "field"
      },
      aria: {
        describedby: status_id
      }
    }

    # Add placeholder if provided
    field_options[:placeholder] = placeholder if placeholder.present?

    # Merge with html_options to ensure they take precedence
    field_options = field_options.merge(html_options)

    # Build the HTML using Rails helpers and string concatenation
    html = ""

    # Container div
    html << "<div class=\"space-y-1\">"

    # Label
    html << form.label(field_name, label, class: "block text-sm font-medium text-gray-700")

    # Relative container for password field and toggle button
    html << "<div class=\"relative\" data-controller=\"visibility\" data-visibility-timeout-value=\"#{timeout}\">"

    # Password field
    html << form.password_field(field_name, field_options)

    # Toggle button with data-action attribute
    html << "<button type=\"button\" class=\"absolute inset-y-0 right-0 flex items-center pr-3 text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 eye-closed\" data-action=\"visibility#togglePassword\" aria-label=\"Show password\" aria-pressed=\"false\">"

    # SVG icon
    html << "<svg class=\"h-5 w-5\" data-visibility-target=\"icon\" fill=\"none\" viewBox=\"0 0 24 24\" stroke=\"currentColor\" aria-hidden=\"true\">"
    html << "<path d=\"M15 12a3 3 0 11-6 0 3 3 0 016 0z\"></path>"
    html << "<path d=\"M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z\"></path>"
    html << "</svg>"

    html << "</button>"

    # Status element for screen readers
    html << "<div id=\"#{status_id}\" class=\"sr-only\" aria-live=\"polite\" data-visibility-target=\"status\">Password is hidden</div>"

    html << "</div>" # Close relative container

    # Optional hint text
    if hint
      html << "<p class=\"text-xs text-gray-500\" id=\"#{field_id}-hint\">#{hint}</p>"
    end

    html << "</div>" # Close main container

    # Return the HTML
    html.html_safe
  end
end
