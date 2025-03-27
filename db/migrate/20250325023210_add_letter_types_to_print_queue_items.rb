class AddLetterTypesToPrintQueueItems < ActiveRecord::Migration[8.0]
  def up
    # Safely add new enum values to letter_type
    # Current values: account_created(0), income_proof_rejected(1), residency_proof_rejected(2),
    # income_threshold_exceeded(3), application_approved(4), registration_confirmation(5), other_notification(6)
    
    # Adding:
    # proof_approved(7), max_rejections_reached(8), proof_submission_error(9), evaluation_submitted(10)
    
    execute <<-SQL
      ALTER TABLE print_queue_items 
      DROP CONSTRAINT IF EXISTS check_print_queue_items_on_letter_type;
      
      ALTER TABLE print_queue_items
      ADD CONSTRAINT check_print_queue_items_on_letter_type
      CHECK (letter_type >= 0 AND letter_type <= 10);
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE print_queue_items 
      DROP CONSTRAINT IF EXISTS check_print_queue_items_on_letter_type;
      
      ALTER TABLE print_queue_items
      ADD CONSTRAINT check_print_queue_items_on_letter_type
      CHECK (letter_type >= 0 AND letter_type <= 6);
    SQL
  end
end
