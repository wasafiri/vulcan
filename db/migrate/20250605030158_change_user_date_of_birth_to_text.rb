class ChangeUserDateOfBirthToText < ActiveRecord::Migration[8.0]
  def up
    # Add a new text column
    add_column :users, :date_of_birth_text, :text
    
    # Copy existing date values as text
    execute <<-SQL
      UPDATE users 
      SET date_of_birth_text = date_of_birth::text 
      WHERE date_of_birth IS NOT NULL
    SQL
    
    # Remove the old date column
    remove_column :users, :date_of_birth
    
    # Rename the new column to the original name
    rename_column :users, :date_of_birth_text, :date_of_birth
  end

  def down
    # Add a new date column
    add_column :users, :date_of_birth_date, :date
    
    # Convert text back to dates (this will only work if the text is in a valid date format)
    # Note: This won't work for encrypted data, but provides a path for rollback if needed
    execute <<-SQL
      UPDATE users 
      SET date_of_birth_date = date_of_birth::date 
      WHERE date_of_birth IS NOT NULL AND date_of_birth ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    SQL
    
    # Remove the old text column
    remove_column :users, :date_of_birth
    
    # Rename the new column to the original name
    rename_column :users, :date_of_birth_date, :date_of_birth
  end
end
