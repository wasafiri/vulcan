class AddNotesToProofReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :proof_reviews, :notes, :text
  end
end
