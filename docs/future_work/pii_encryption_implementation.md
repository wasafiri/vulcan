# PII Encryption Implementation Guide

Rails 8 ActiveRecord Encryption protects all personally identifiable data in MAT Vulcan. This guide explains **what is encrypted, how queries still work, and how to backfill, test, and rotate keys**.

---

## 1 · What We Encrypt

| Model / Table | Column | Deterministic? | Why |
|---------------|--------|----------------|-----|
| `users` | `email`, `phone`, `ssn_last4` | **Yes** | We must query & index them |
|            | `password_digest` | No | Hash is already random; extra layer |
|            | `physical_address_1/2`, `city`, `state`, `zip_code` | No | Not queried directly |
| `totp_credentials` | `secret` | No | Never queried |
| `sms_credentials` | `code_digest` | No | Never queried |
| `webauthn_credentials` | `public_key` | No | Never queried |

**Deterministic = identical plaintext → identical ciphertext → indexable.** Trade-off: slight leakage of equality; document in security controls.

---

## 2 · Model Declarations

```ruby
# app/models/user.rb
class User < ApplicationRecord
  encrypts :email, :phone, :ssn_last4, deterministic: true
  encrypts :password_digest,
           :physical_address_1, :physical_address_2,
           :city, :state, :zip_code
end

class TotpCredential  < ApplicationRecord; encrypts :secret end
class SmsCredential   < ApplicationRecord; encrypts :code_digest end
class WebauthnCredential < ApplicationRecord; encrypts :public_key end
```

---

## 3 · Query Work-Around (Rails 8 bug)

`extend_queries` is flaky, so we provide helper lookups:

```ruby
# user.rb
def self.find_by_email(email)
  return if email.blank?
  encrypted = User.new(email:).read_attribute('email_encrypted')
  return if encrypted.nil?               # encryption failed
  find_by(email_encrypted: encrypted)
end

def self.exists_with_email?(email, excluding_id: nil)
  encrypted = User.new(email:).read_attribute('email_encrypted')
  return false if encrypted.nil?
  scope = where(email_encrypted: encrypted)
  scope = scope.where.not(id: excluding_id) if excluding_id
  scope.exists?
end
```

Use these helpers **everywhere** instead of `find_by(email:)`.

---

## 4 · Migration Blueprint

```bash
bin/rails g migration AddEncryptedColumnsWithIndexes
```

```ruby
class AddEncryptedColumnsWithIndexes < ActiveRecord::Migration[8.0]
  def change
    change_table :users do |t|
      t.binary :email_encrypted;  t.string :email_encrypted_iv
      t.binary :phone_encrypted;  t.string :phone_encrypted_iv
      t.binary :ssn_last4_encrypted; t.string :ssn_last4_encrypted_iv
      t.binary :password_digest_encrypted; t.string :password_digest_encrypted_iv
      t.binary :physical_address_1_encrypted; t.string :physical_address_1_encrypted_iv
      # ... rest of address fields ...
    end

    %i[totp_credentials sms_credentials webauthn_credentials].each do |tbl|
      change_table tbl do |t|
        t.binary :"#{tbl.to_s.singularize}_encrypted"
        t.string :"#{tbl.to_s.singularize}_encrypted_iv"
      end
    end

    add_index :users, :email_encrypted,  unique: true
    add_index :users, :phone_encrypted,  unique: true, where: 'phone_encrypted IS NOT NULL'
  end
end
```

Run: `bin/rails db:migrate`

---

## 5 · Backfill Task (idempotent)

```ruby
# lib/tasks/pii.rake
namespace :pii do
  desc 'Encrypt existing plaintext PII'
  task backfill: :environment do
    User.find_each do |u|
      next if u.email_encrypted.present?
      u.update_columns(email: u.email, phone: u.phone, ssn_last4: u.ssn_last4)
    end
    TotpCredential.find_each  { |c| c.update_columns(secret: c.secret)   if c.secret_encrypted.blank? }
    SmsCredential.find_each   { |c| c.update_columns(code_digest: c.code_digest) if c.code_digest_encrypted.blank? }
    WebauthnCredential.find_each { |c| c.update_columns(public_key: c.public_key) if c.public_key_encrypted.blank? }
    puts 'Backfill complete.'
  end
end
```

Verify: `bin/rails runner "puts User.where(email_encrypted: nil).count"`

---

## 6 · Parameter Filtering

```ruby
Rails.application.config.filter_parameters += [
  :email, :phone, :ssn_last4, :password, :password_confirmation,
  /_encrypted\z/, /_encrypted_iv\z/
]
```

---

## 7 · Tests You Should Have

```ruby
it 'encrypts deterministically and queries work' do
  user = create(:user, email: 'a@b.com', phone: '555-123-4567')
  expect(user.email_encrypted).to be_present
  expect(User.find_by_email('a@b.com')).to eq(user)
  expect { create(:user, email: 'a@b.com') }.to raise_error(ActiveRecord::RecordNotUnique)
end
```

Add similar specs for phone and credential models.

---

## 8 · Deployment Phases

1. **Add encrypted columns + code** (no user impact)  
2. **Backfill** (maintenance window)  
3. **Remove plaintext columns** (after thorough staging tests)

Checklist before each phase:

- Test auth & registration  
- Grep for `User\.find_by(email:` etc. – none should remain  
- Verify no sensitive data appears in logs  
- Monitor query plans for encrypted indexes

---

## 9 · Key Rotation (when required)

```yaml
# credentials.yml.enc
active_record_encryption:
  primary_key: <new>
  deterministic_key: <new>
  key_derivation_salt: <new>
  previous:
    - primary_key: <old>
      deterministic_key: <old>
      key_derivation_salt: <old>
```

```bash
bin/rails pii:rotate_keys   # run task that re-saves each record
bin/rails pii:verify        # confirm ciphertext updated
```

Remove the `previous:` block once rotated.

---

## 10 · Gotchas

* **NULL ciphertexts** match everything—ensure backfill fills all rows.  
* **Direct SQL** to plaintext columns will break; always use helpers.  
* **Binary columns** increase row size; monitor storage and query speed.  
* **Backups** require keys—store them with disaster-recovery docs.  
* **Third-party gems** may still query `users.email`; audit & patch.