# frozen_string_literal: true

class AddNeedsDuplicateReviewToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :needs_duplicate_review, :boolean, default: false, null: false
  end
end
