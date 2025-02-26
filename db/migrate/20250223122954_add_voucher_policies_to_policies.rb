class AddVoucherPoliciesToPolicies < ActiveRecord::Migration[8.0]
  def up
    # First ensure we have the base policies table
    unless table_exists?(:policies)
      create_table :policies do |t|
        t.string :key
        t.integer :value
        t.timestamps
      end
    end

    # Add default voucher values for each disability type
    default_values = {
      'voucher_value_hearing_disability' => 500,
      'voucher_value_vision_disability' => 500,
      'voucher_value_speech_disability' => 500,
      'voucher_value_mobility_disability' => 500,
      'voucher_value_cognition_disability' => 500,
      'voucher_validity_period_months' => 6,
      'voucher_minimum_redemption_amount' => 10
    }

    default_values.each do |key, value|
      execute <<-SQL
        INSERT INTO policies (key, value, created_at, updated_at)
        VALUES ('#{key}', #{value}, NOW(), NOW())
        ON CONFLICT (key) DO NOTHING;
      SQL
    end

    add_index :policies, :key, unique: true, if_not_exists: true
  end

  def down
    # Remove the voucher-related policies
    Policy.where(key: [
      'voucher_value_hearing_disability',
      'voucher_value_vision_disability',
      'voucher_value_speech_disability',
      'voucher_value_mobility_disability',
      'voucher_value_cognition_disability',
      'voucher_validity_period_months',
      'voucher_minimum_redemption_amount'
    ]).delete_all
  end
end
