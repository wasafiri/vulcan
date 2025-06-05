class FixEncryptionSchemaToRemoveEncryptedColumns < ActiveRecord::Migration[8.0]
  # Create: bin/rails generate migration FixEncryptionSchemaForRails8
  def change
    # Increase column sizes for encrypted JSON storage (Rails documentation recommends +255 bytes overhead)
    # For short text in western alphabets: original + 255 bytes
    # For potential non-western text: multiply by 4

    change_column :users, :email, :string, limit: 510        # Original 255 + 255 overhead
    change_column :users, :phone, :string, limit: 300        # Phone numbers are short
    change_column :users, :ssn_last4, :string, limit: 300    # SSN is short
    change_column :users, :password_digest, :string, limit: 500 # BCrypt hashes + overhead
    change_column :users, :physical_address_1, :string, limit: 1000 # Addresses can be long
    change_column :users, :physical_address_2, :string, limit: 1000
    change_column :users, :city, :string, limit: 500
    change_column :users, :state, :string, limit: 300
    change_column :users, :zip_code, :string, limit: 300

    # For credential secrets, use text columns since they can be large
    change_column :totp_credentials, :secret, :text if column_exists?(:totp_credentials, :secret)
    change_column :sms_credentials, :code_digest, :text if column_exists?(:sms_credentials, :code_digest)
    change_column :webauthn_credentials, :public_key, :text if column_exists?(:webauthn_credentials, :public_key)

    # Add proper indexes on the plaintext columns (Rails will handle encryption transparently)
    # For deterministic encryption, we can index the columns
    add_index :users, :email, unique: true, name: 'index_users_on_email_unique'
    add_index :users, :phone, unique: true, name: 'index_users_on_phone_unique', where: 'phone IS NOT NULL'
  end
end
