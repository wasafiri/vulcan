# frozen_string_literal: true

module Users
  class Constituent < User
    # Associations
    has_many :applications, foreign_key: :user_id, dependent: :destroy
    has_many :evaluations
    has_many :assigned_evaluators, through: :evaluations, source: :evaluator
    # Removed unconditional validation: validate :must_have_at_least_one_disability

    # Callbacks
    before_validation :check_for_duplicates, on: :create

    # Enums
    enum :communication_preference, { email: 0, letter: 1 }

    # Encryption
    encrypts :date_of_birth, deterministic: true

    # Scopes
    scope :needs_evaluation, -> { joins(:applications).where(applications: { status: :approved }) }
    scope :active, -> { where.not(status: %i[withdrawn rejected expired]) }
    scope :ytd, lambda {
      where(created_at: Date.new(Date.current.year >= 7 ? Date.current.year : Date.current.year - 1, 7, 1)..)
    }

    DISABILITY_TYPES = %w[hearing vision speech mobility cognition].freeze

    # Define disability attributes with defaults
    DISABILITY_TYPES.each do |type|
      attribute :"#{type}_disability", :boolean, default: false
    end

    DISABILITY_TYPES.each do |type|
      define_method("#{type}_disability=") do |value|
        super(ActiveModel::Type::Boolean.new.cast(value))
      end
    end

    # Optional: Method to check inherited columns
    def self.inherited_columns
      column_names
    end

    def active_application?
      active_application.present?
    end

    def active_application
      applications.active.order(application_date: :desc).first
    end

    # Public method to check if any disability is selected
    def has_disability_selected?
      hearing_disability || vision_disability || speech_disability || mobility_disability || cognition_disability
    end

    # Class methods for encrypted lookups
    def self.find_duplicates(first_name, last_name, date_of_birth)
      Rails.logger.debug "*** find_duplicates called with: first_name=#{first_name}, last_name=#{last_name}, date_of_birth=#{date_of_birth} (#{date_of_birth.class})"
      
      return none if first_name.blank? || last_name.blank? || date_of_birth.blank?

      # Ensure consistent date format for encryption
      formatted_date = case date_of_birth
                      when String then date_of_birth
                      when Date then date_of_birth.strftime('%Y-%m-%d')
                      else return none
                      end
      
      Rails.logger.debug "*** Using formatted_date: #{formatted_date} (#{formatted_date.class})"

      # Check all existing records and their dates
      all_matching_name = where('LOWER(first_name) = ? AND LOWER(last_name) = ?', 
                             first_name.downcase, 
                             last_name.downcase)
      
      if all_matching_name.exists?
        Rails.logger.debug "*** Found #{all_matching_name.count} name matches"
        all_matching_name.each do |user|
          Rails.logger.debug "*** User #{user.id}: DOB=#{user.date_of_birth} (#{user.date_of_birth.class}), formatted=#{user.date_of_birth.is_a?(Date) ? user.date_of_birth.strftime('%Y-%m-%d') : user.date_of_birth}"
        end
      end

      # Debug the query
      query = where('LOWER(first_name) = ? AND LOWER(last_name) = ? AND date_of_birth = ?',
                   first_name.downcase,
                   last_name.downcase,
                   formatted_date)
      Rails.logger.debug "*** Duplicate query SQL: #{query.to_sql}"
      results = query.pluck(:id, :first_name, :last_name)
      Rails.logger.debug "*** Duplicate query results: #{results.inspect}, count: #{results.count}"
      query
    end

    private

    def check_for_duplicates
      Rails.logger.debug "*** Checking for duplicates: first_name=#{first_name}, last_name=#{last_name}, date_of_birth=#{date_of_birth} (#{date_of_birth.class})"
      return unless first_name.present? && last_name.present? && date_of_birth.present?

      # Look for potential duplicates using the class method
      duplicates = self.class.find_duplicates(first_name, last_name, date_of_birth)
      
      # Don't exclude self since this is a new record
      has_duplicates = duplicates.exists?
      self.needs_duplicate_review = has_duplicates
      Rails.logger.debug "*** Found duplicates: #{has_duplicates} - setting needs_duplicate_review to #{needs_duplicate_review}"
    end

    def must_have_at_least_one_disability
      return if hearing_disability || vision_disability || speech_disability || mobility_disability || cognition_disability

      errors.add(:base, 'At least one disability must be selected.')
    end
  end
end
