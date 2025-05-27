# frozen_string_literal: true

module Users
  class Constituent < User
    # Associations
    has_many :applications, foreign_key: :user_id, dependent: :destroy
    has_many :evaluations
    has_many :assigned_evaluators, through: :evaluations, source: :evaluator
    # Removed unconditional validation: validate :must_have_at_least_one_disability

    # Enums
    enum :communication_preference, { email: 0, letter: 1 }

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

    private

    def must_have_at_least_one_disability
      return if hearing_disability || vision_disability || speech_disability || mobility_disability || cognition_disability

      errors.add(:base, 'At least one disability must be selected.')
    end
  end
end
