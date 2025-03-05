class ConsolidateVoucherStatuses < ActiveRecord::Migration[8.0]
  def up
    # Update all "issued" vouchers to "active" status
    execute <<-SQL
      UPDATE vouchers SET status = 1 WHERE status = 0;
    SQL
  end

  def down
    # This migration is not reversible as we're consolidating statuses
    # and can't determine which vouchers were previously "issued" vs "active"
  end
end
