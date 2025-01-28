class RenameRecommendedAccessoryIdsToNotesInEvaluations < ActiveRecord::Migration[8.0]
  def change
    if column_exists?(:evaluations, :recommended_accessory_ids)
      if !column_exists?(:evaluations, :notes)
        # Rename the column if 'notes' does not exist
        rename_column :evaluations, :recommended_accessory_ids, :notes
        # Change the column type to text with default and null constraints
        change_column :evaluations, :notes, :text, default: "", null: false
        puts "Renamed 'recommended_accessory_ids' to 'notes' and updated column type."
      else
        # If both columns exist, remove the redundant 'recommended_accessory_ids' column
        remove_column :evaluations, :recommended_accessory_ids
        puts "Removed redundant 'recommended_accessory_ids' column."
      end
    else
      puts "No action needed: 'recommended_accessory_ids' does not exist."
    end
  end
end
