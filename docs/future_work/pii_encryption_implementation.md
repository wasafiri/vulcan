# PII Encryption Implementation Guide

This document outlines steps to encrypt sensitive database columns using Rails ActiveRecord Encryption to protect PII.

## Columns to Encrypt
Per docs/security/controls.yaml (DATA-001), we need to encrypt:
- `users.password_digest`
- `users.ssn_last4`
- `users.email`
- `users.phone`
- `users.physical_address_1`
- `users.physical_address_2`
- `users.city`
- `users.state`
- `users.zip_code`
- `totp_credentials.secret`
- `sms_credentials.code_digest`
- `webauthn_credentials.public_key`

## Prerequisites
1. Rails 8+ application.
2. ActiveRecord Encryption configured (initializer in `config/initializers/`).
3. Master key available (`config/credentials.yml.enc` & `config/master.key`).
4. Ensure `config.active_record.encryption.add_to_filter_parameters = true`.

## Implementation Steps

### 1. Add `encrypts` macros to models
In `app/models/user.rb`, add:
```ruby
class User < ApplicationRecord
  encrypts :email, deterministic: true
  encrypts :phone, deterministic: true
  encrypts :ssn_last4, deterministic: true
  encrypts :password_digest
  encrypts :physical_address_1
  encrypts :physical_address_2
  encrypts :city
  encrypts :state
  encrypts :zip_code
end
```

In `app/models/totp_credential.rb`:
```ruby
class TotpCredential < ApplicationRecord
  encrypts :secret
end
```

In `app/models/sms_credential.rb`:
```ruby
class SmsCredential < ApplicationRecord
  encrypts :code_digest
end
```

In `app/models/webauthn_credential.rb`:
```ruby
class WebauthnCredential < ApplicationRecord
  encrypts :public_key
end
```

### 2. Generate and run migrations
Create a migration to add encrypted columns:
```bash
bin/rails generate migration AddEncryptedColumns
```
Then edit the generated migration:
```ruby
class AddEncryptedColumns < ActiveRecord::Migration[8.0]
  def change
    change_table :users do |t|
      t.binary :email_encrypted
      t.string :email_encrypted_iv
      t.binary :phone_encrypted
      t.string :phone_encrypted_iv
      t.binary :ssn_last4_encrypted
      t.string :ssn_last4_encrypted_iv
      t.binary :password_digest_encrypted
      t.string :password_digest_encrypted_iv
      t.binary :physical_address_1_encrypted
      t.string :physical_address_1_encrypted_iv
      t.binary :physical_address_2_encrypted
      t.string :physical_address_2_encrypted_iv
      t.binary :city_encrypted
      t.string :city_encrypted_iv
      t.binary :state_encrypted
      t.string :state_encrypted_iv
      t.binary :zip_code_encrypted
      t.string :zip_code_encrypted_iv
    end

    change_table :totp_credentials do |t|
      t.binary :secret_encrypted
      t.string :secret_encrypted_iv
    end

    change_table :sms_credentials do |t|
      t.binary :code_digest_encrypted
      t.string :code_digest_encrypted_iv
    end

    change_table :webauthn_credentials do |t|
      t.binary :public_key_encrypted
      t.string :public_key_encrypted_iv
    end
  end
end
```
Run `bin/rails db:migrate`.

### 3. Backfill existing data
Create a rake task (`lib/tasks/backfill_pii_encryption.rake`):
```ruby
namespace :pii do
  desc "Backfill encrypted PII columns"
  task backfill: :environment do
    User.find_each do |user|
      user.update(
        email: user.email,
        phone: user.phone,
        ssn_last4: user.ssn_last4,
        physical_address_1: user.physical_address_1,
        physical_address_2: user.physical_address_2,
        city: user.city,
        state: user.state,
        zip_code: user.zip_code
      )
    end
    TotpCredential.find_each    { |c| c.update(secret: c.secret) }
    SmsCredential.find_each     { |c| c.update(code_digest: c.code_digest) }
    WebauthnCredential.find_each { |c| c.update(public_key: c.public_key) }
  end
end
```
Run `bin/rails pii:backfill`.

### 4. Remove legacy plaintext columns
After verifying backfill, drop the old columns:
```ruby
class RemovePlaintextPiiColumns < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :email, :string
    remove_column :users, :phone, :string
    remove_column :users, :ssn_last4, :string
    remove_column :users, :physical_address_1, :string
    remove_column :users, :physical_address_2, :string
    remove_column :users, :city, :string
    remove_column :users, :state, :string
    remove_column :users, :zip_code, :string
  end
end
```
Run `bin/rails db:migrate`.

### 5. Update controllers and strong parameters
In controllers handling user updates (e.g., `UsersController`, Devise `RegistrationsController`), permit PII params as before:
```ruby
def user_params
  params.require(:user).permit(
    :email, :phone, :ssn_last4,
    :physical_address_1, :physical_address_2,
    :city, :state, :zip_code,
    ...
  )
end
``` No changes to param names are needed.

### 6. Update test suites
- **Factories**: leave attributes as plaintext (e.g., `email { "user@example.com" }`). Encryption runs automatically.
- **Model tests**: add tests asserting encrypted columns exist and that reading/writing works:
```ruby
test "email is encrypted in DB" do
  user = create(:user, email: "a@b.com")
  assert user.respond_to?(:email_encrypted)
  assert_not_nil user.email_encrypted
  assert_equal "a@b.com", user.email
end
```
- **Parameter filter tests**: ensure logs filter out new `*_encrypted` and `*_iv` params.

### 7. Update parameter filtering
In `config/initializers/filter_parameter_logging.rb`, add:
```ruby
Rails.application.config.filter_parameters += [ /_encrypted\z/, /_encrypted_iv\z/ ]
```

## Verification & Rollout
1. Create a test user and verify encrypted columns populate.
2. Run full test suite — all tests should pass with encryption enabled.
3. Deploy to staging, run backfill, smoke test critical user flows.
4. Deploy to production, run backfill during maintenance, then merge migration to remove legacy columns. 