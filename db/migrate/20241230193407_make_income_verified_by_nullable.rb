class MakeIncomeVerifiedByNullable < ActiveRecord::Migration[8.0]
  def change
    change_column_null :applications, :income_verified_by_id, true
  end
end
