class ModifyEmailUniquenessForDependents < ActiveRecord::Migration[8.0]
  def change
    # This migration has been disabled due to PostgreSQL compatibility issues
    # The fix is implemented in a subsequent migration: FixEmailUniquenessForDependents
    #
    # Original intent: Allow dependents to share emails with guardians
    # Solution: Handle this logic in the application layer instead of database constraints
  end
end
