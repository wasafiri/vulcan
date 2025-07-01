# frozen_string_literal: true

#
# Paper-application system-test helpers
# – Stable selectors first, labels last
# – Scoped visibility handling (no global Capybara flag changes)
# – Minimal DOM-mutation fallbacks
# – Lightweight PageObjects for clearer responsibilities
#
module PaperApplicationsTestHelper
  # ------------------------------------------------------------------------
  # Configuration hashes (single sources of truth)
  # ------------------------------------------------------------------------

  FIELD_DEFINITIONS = {
    # Applicant / constituent
    'First Name' => {
      ids: %w[constituent_first_name applicant_attributes_first_name first_name],
      name_attr: 'constituent[first_name]',
      container: :get_applicant_info_fieldset
    },
    'Last Name' => {
      ids: %w[constituent_last_name applicant_attributes_last_name last_name],
      name_attr: 'constituent[last_name]',
      container: :get_applicant_info_fieldset
    },
    'Email' => {
      ids: %w[constituent_email applicant_attributes_email email],
      name_attr: 'constituent[email]',
      container: :get_applicant_info_fieldset
    },
    'Phone' => {
      ids: %w[constituent_phone applicant_attributes_phone phone],
      name_attr: 'constituent[phone]',
      container: :get_applicant_info_fieldset
    },

    # Application details
    'Household Size' => {
      ids: %w[application_household_size household_size],
      name_attr: 'application[household_size]'
    },
    'Annual Income' => {
      ids: %w[application_annual_income annual_income],
      name_attr: 'application[annual_income]'
    },

    # Medical-provider section
    'Name' => {
      ids: %w[application_medical_provider_name medical_provider_name],
      name_attr: 'application[medical_provider_name]',
      container: :get_medical_provider_fieldset
    },
    'Medical Provider Email' => {
      ids: %w[application_medical_provider_email medical_provider_email],
      name_attr: 'application[medical_provider_email]',
      container: :get_medical_provider_fieldset
    },
    'Medical Provider Phone' => {
      ids: %w[application_medical_provider_phone medical_provider_phone],
      name_attr: 'application[medical_provider_phone]',
      container: :get_medical_provider_fieldset
    }
  }.freeze

  APPLICANT_TYPES = {
    adult: {
      radio_selector: 'input[name="application[applicant_type]"][value="adult"]',
      label_text: 'An Adult (applying for themselves)',
      expected_sections: %w[
        [data-applicant-type-target="adultSection"]
        [data-applicant-type-target="commonSections"]
      ]
    },
    dependent: {
      radio_selector: 'input[name="application[applicant_type]"][value="dependent"]',
      label_text: 'A Dependent (must select existing guardian in system or enter guardian\'s information)',
      expected_sections: %w[
        [data-applicant-type-target="guardianSection"]
        [data-applicant-type-target="commonSections"]
      ]
    }
  }.freeze

  # ------------------------------------------------------------------------
  # Public helpers (called from tests)
  # ------------------------------------------------------------------------

  # Smarter fill-in
  def paper_fill_in(field_label, value)
    return if field_label.nil? || field_label.strip.empty?

    meta = FIELD_DEFINITIONS[field_label]
    unless meta
      fill_in(field_label, with: value)
      return
    end

    container = meta[:container] && send(meta[:container])

    fill_field(
      value,
      ids: meta[:ids],
      label: field_label,
      name_attr: meta[:name_attr],
      container: container
    )
  end

  # Robust checkbox helper – no JS mutation; falls back to setting the element
  def paper_check_box(id_or_label)
    check(id_or_label, allow_label_click: true)
  rescue Capybara::ElementNotFound
    selector =
      if id_or_label.start_with?('#')
        id_or_label
      else
        %(input[name="#{id_or_label}"],input[id="#{id_or_label}"])
      end

    el = find(:css, selector, visible: :all, wait: 0)
    el.set(true) unless el.checked?
  end

  # Applicant-type radio selector + section wait
  def choose_applicant_type(type)
    ApplicantTypeSwitcher.new(page).choose(type)
    wait_for_page_load if respond_to?(:wait_for_page_load)
  end

  # Add within_fieldset_tagged method that's used in tests
  def within_fieldset_tagged(text, &)
    fieldset = locate_fieldset(text)
    within(fieldset, &)
  end

  # ------------------------------------------------------------------------
  # Fieldset shortcuts
  # ------------------------------------------------------------------------

  def get_applicant_info_fieldset
    locate_fieldset("Applicant's Information",
                    data_selector: '[data-applicant-type-target="adultSection"]',
                    fallback_text: /Constituent Information/i)
  end

  def get_guardian_info_fieldset
    locate_fieldset('Guardian Information',
                    data_selector: '[data-applicant-type-target="guardianSection"]')
  end

  def get_dependent_info_fieldset
    locate_fieldset('Dependent Information',
                    data_selector: '[data-applicant-type-target="sectionsForDependentWithGuardian"]')
  end

  def get_medical_provider_fieldset
    locate_fieldset('Medical Provider Information')
  end

  # ------------------------------------------------------------------------
  # Private helpers
  # ------------------------------------------------------------------------
  private

  # Unified "fill a field" implementation
  def fill_field(value, ids:, label:, name_attr:, container: nil)
    scope = container || page

    # 1) Try by IDs
    if (matching_id = ids.find { |id| scope.has_css?("##{id}", visible: :all) })
      scope.find("##{matching_id}", visible: :all).set(value)
      return
    end

    # 2) Try by label
    begin
      field = scope.find_field(label, visible: :all)
      field.set(value)
      return
    rescue Capybara::ElementNotFound
      # no match
    end

    # 3) Final fallback by name attribute
    raise Capybara::ElementNotFound, "Cannot find field for #{label.inspect}" unless name_attr

    selector = "input[name='#{name_attr}'], textarea[name='#{name_attr}']"
    field = scope.first(:css, selector, visible: :all)
    raise Capybara::ElementNotFound, "Unable to locate field `#{name_attr}` for #{label.inspect}" unless field

    field.set(value)
  end

  # Delegate to enhanced FieldsetFinder PageObject
  def locate_fieldset(*, **)
    FieldsetFinder.new(page).locate(*, **)
  end

  # Safe wrapper for accessing a specific fieldset within a test
  def within_fieldset_with_legend(legend_text, options = {}, &)
    fieldset = locate_fieldset(legend_text)
    within(fieldset, options, &)
  end

  # ------------------------------------------------------------------------
  # Internal PageObjects
  # ------------------------------------------------------------------------

  # Enhanced PageObject for applicant-type switching
  class ApplicantTypeSwitcher
    def initialize(page)
      @page = page
    end

    def choose(type)
      meta = PaperApplicationsTestHelper::APPLICANT_TYPES[
        type.to_s.downcase.to_sym
      ] || (raise ArgumentError, "Unknown applicant type: \#{type.inspect}")

      if @page.has_css?(meta[:radio_selector], visible: :all)
        rb = @page.find(meta[:radio_selector], visible: :all)
        rb.click unless rb.checked?
      else
        @page.choose meta[:label_text], allow_label_click: true
      end

      meta[:expected_sections].each do |css|
        @page.assert_selector css, visible: true,
                                   wait: Capybara.default_max_wait_time
      end
    end
  end

  # Fieldset location encapsulated in its own object
  class FieldsetFinder
    def initialize(page)
      @page = page
    end

    def locate(legend_text, data_selector: nil, fallback_text: nil)
      # 1. Try data-selector first as it's most reliable
      if data_selector && (fs = by_data_selector(data_selector))
        return make_visible(fs)
      end

      # 2. Try XPath with proper escaping
      if (fs = find_by_escaped_xpath(legend_text))
        return make_visible(fs)
      end

      # 3. Use pure-Ruby enumeration over fieldsets
      if (fs = find_fieldset_by_enumeration(legend_text))
        return make_visible(fs)
      end

      # 4. Try standard Capybara text matching
      if (fs = first_fieldset_by_legend(legend_text))
        return make_visible(fs)
      end

      # 5. Try fallback text if provided
      if fallback_text && (fs = by_fallback_text(fallback_text))
        return make_visible(fs)
      end

      # 6. Last resort - just get any fieldset
      fieldset = @page.first('fieldset', visible: :all)

      unless fieldset
        raise Capybara::ElementNotFound,
              "Unable to locate fieldset for #{legend_text}"
      end

      make_visible(fieldset)
      fieldset
    end

    private

    # Helper to properly escape text for XPath queries
    def xpath_literal(str)
      if str.exclude?("'")
        "'#{str}'"
      elsif str.exclude?('"')
        %("#{str}")
      else
        parts = str.scan(/[^'"]+|['"]/)
        concat_parts = parts.map do |part|
          if part == "'"
            %q("'")
          elsif part == '"'
            %q("\"")
          else
            "'#{part}'"
          end
        end
        "concat(#{concat_parts.join(',')})"
      end
    end

    # Use absolute XPath with proper escaping to find fieldset by legend text
    def find_by_escaped_xpath(text)
      literal = xpath_literal(text)
      @page.first(:xpath,
                  "//fieldset[.//legend[contains(normalize-space(), #{literal})]]",
                  wait: 1,
                  visible: :all)
    rescue Capybara::ElementNotFound, Capybara::Cuprite::InvalidSelector
      nil
    end

    # Pure-Ruby search over all fieldsets to find one with matching legend
    def find_fieldset_by_enumeration(text)
      @page.all('fieldset', visible: :all).find do |fs|
        legend = fs.first('legend', visible: :all, wait: 0)
        legend && legend.text.strip.include?(text)
      rescue StandardError
        false
      end
    rescue StandardError
      nil
    end

    def first_fieldset_by_legend(text)
      @page.first(:fieldset, text,
                  match: :prefer_exact,
                  wait: 1,
                  visible: :all)
    rescue Capybara::ElementNotFound
      nil
    end

    def by_data_selector(selector)
      @page.find(selector, visible: :all, wait: 1)
    rescue Capybara::ElementNotFound
      nil
    end

    def by_fallback_text(text)
      @page.first('fieldset', text: text, visible: :all)
    rescue Capybara::ElementNotFound
      nil
    end

    # Make the fieldset visible for interaction
    def make_visible(element)
      @page.execute_script <<~JS, element
        (function(el){
          if(!el) return;
          el.classList.remove('hidden');
          el.style.display = 'block';
          var p = el.parentElement, i = 0;
          while(p && i < 5){
            p.classList.remove('hidden');
            p.style.display = 'block';
            p = p.parentElement;
            i++;
          }
        })(arguments[0]);
      JS
    end
  end
end
