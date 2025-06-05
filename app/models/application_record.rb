# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  include ActiveRecord::Encryption # Explicitly include ActiveRecord Encryption
end
