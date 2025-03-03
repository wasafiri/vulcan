class AddPaperToProofReviewSubmissionMethod < ActiveRecord::Migration[8.0]
  def up
    # There's a mismatch between the database schema and the model definition.
    # The submission_method column is a string, but the enum in the model is defined with integer values.
    # Since there are no records in the table yet, we can safely change the column type to integer.

    # First, change the column type to integer
    change_column :proof_reviews, :submission_method, :integer, using: "submission_method::integer"

    # We've already updated the model to include 'paper' as a valid option.
    puts "Changed submission_method column to integer type and added 'paper' as a valid option"
  end

  def down
    # Change the column back to string
    change_column :proof_reviews, :submission_method, :string
    puts "Changed submission_method column back to string type"
  end
end
