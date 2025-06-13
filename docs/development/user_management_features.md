# User Management Features

---

## 1 · Signup Deduplication

### 1.1 · Phone Uniqueness (Hard)

* **DB index** on `users.phone`.
* `validates :phone, uniqueness: true`.
* Normalisation before validation:

```ruby
before_validation :format_phone_number

def format_phone_number
  return if phone.blank?
  cleaned = phone.gsub(/\D/, '')
  cleaned = cleaned.sub(/^1/, '') if cleaned.length == 11
  self.phone = "#{cleaned[0..2]}-#{cleaned[3..5]}-#{cleaned[6..9]}" if cleaned.length == 10
end
```

### 1.2 · Name + DOB Flag (Soft)

```ruby
# RegistrationsController#create
@user.needs_duplicate_review = true if potential_duplicate_found?(@user)
```

```ruby
def potential_duplicate_found?(u)
  return false unless u.first_name && u.last_name && u.date_of_birth
  User.exists?(["LOWER(first_name)=? AND LOWER(last_name)=? AND date_of_birth=?",
               u.first_name.downcase, u.last_name.downcase, u.date_of_birth])
end
```

*Flag is invisible to the end user; admins review later.*

### 1.3 · Admin “Needs Review” Badge

```erb
<% if user.needs_duplicate_review? %>
  <span class="rounded-full bg-yellow-100 text-yellow-800 px-2.5 py-0.5 text-xs">Needs Review</span>
<% end %>
```

---

## 2 · Test Selectors (`data-testid`)

| Element | Pattern | Example |
|---------|---------|---------|
| Form | `{feature}-form` | `sign-in-form` |
| Input | `{name}-input` | `email-input` |
| Button | `{action}-button` | `submit-button` |
| Modal | `{feature}-modal` | `confirmation-modal` |
| List / item | `{thing}-list` / `{thing}-item` | `users-list` |

```erb
<form data-testid="sign-in-form">
  <input type="email"    data-testid="email-input">
  <input type="password" data-testid="password-input">
  <button data-testid="sign-in-button">Sign In</button>
</form>
```

Test usage:

```ruby
within '[data-testid="sign-in-form"]' do
  fill_in  '[data-testid="email-input"]',    with: 'user@example.com'
  fill_in  '[data-testid="password-input"]', with: 'password'
  click_button '[data-testid="sign-in-button"]'
end
```

Priority areas: **Auth forms → Nav → Profile → Application forms → Admin panels**.

---

## 3 · Factory Patterns

```ruby
# Basic
create(:user)
create(:constituent, :verified)

# Guardian / dependent
guardian  = create(:user, :with_dependents)   # many
dependent = create(:user, :with_guardian)

# Explicit relationship
create(:guardian_relationship,
       guardian_user: guardian,
       dependent_user: dependent,
       relationship_type: 'Parent')

# Avoid uniqueness clashes
create(:user, email: generate(:email), phone: generate(:phone))
```

---

## 4 · Model Test Examples

```ruby
# Validation
test 'phone uniqueness' do
  create(:user, phone: '555-123-4567')
  dup = build(:user, phone: '555-123-4567')
  assert_not dup.valid?
end

# Callback
test 'phone formatted' do
  u = create(:user, phone: '(555) 123-4567')
  assert_equal '555-123-4567', u.phone
end

# Private helper
test 'private helper' do
  u = build(:user)
  assert u.send(:some_private_helper)
end
```

---

## 5 · Future Work

* **Duplicate review UI**: merge accounts, track resolutions.  
* **Enhanced dedup**: fuzzy address match, ML scoring.  
* **Bulk scanning**: legacy data cleanup.  
* **`data-testid` expansion** & tooling to strip in production builds.