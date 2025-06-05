class AddDependentContactInfoToUsers < ActiveRecord::Migration[8.0]
  def change
    # Add optional contact fields for dependents
    # These fields allow dependents to have their own contact information
    # If blank, communications will default to guardian's contact info
    add_column :users, :dependent_email, :string, comment: 'Optional email for dependents; if blank, uses guardian email'
    add_column :users, :dependent_phone, :string, comment: 'Optional phone for dependents; if blank, uses guardian phone'
    
    # Add indexes for performance when querying dependent contact info
    add_index :users, :dependent_email
    add_index :users, :dependent_phone
  end
end
