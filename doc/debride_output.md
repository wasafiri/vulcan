# Debride Analysis Results

This document contains the results of running debride against the application, which identifies methods that might not be called. This analysis was generated based on production.log data on April 30, 2025.

## Method Whitelisting

The following methods were explicitly whitelisted in our analysis:
```
assign_voucher
authenticate_user!
bulk_update
change
create
create_credential
credential_success
current_user
down
edit
index
new
new_credential
new_test_email
require_login
setup
show
up
update
update_proof_status
webauthn_creation_options
```

## Potentially Unused Methods

Debride identified the following methods as potentially uncalled:

**Note:** Controller actions previously listed here have been checked against `bin/rails routes --unused`. According to that analysis, these actions are associated with used routes, although debride's static analysis still flags them as potentially uncalled within the application code. The remaining methods listed below are not directly tied to routes and require further code analysis to confirm usage.

### Controllers

#### AccountRecoveryController

#### Admin::ApplicationsController
- `filter_conditions` (app/controllers/admin/applications_controller.rb:769-783) (removed)
- `load_certification_events` (app/controllers/admin/applications_controller.rb:537-563) (removed)

#### Admin::ConstituentsController

#### Admin::EmailTemplatesController

#### Admin::InvoicesController

#### Admin::PaperApplicationsController

#### Admin::PoliciesController
- `set_policies` (app/controllers/admin/policies_controller.rb:99-101): 100

#### Admin::PrintQueueController

#### Admin::ProductsController

#### Admin::ProofReviewsController

#### Admin::RecoveryRequestsController

#### Admin::ReportsController

#### Admin::UsersController
- `income_verified_applications` (app/models/user.rb:51)

#### NotificationsController

#### PasswordsController
- `password_params` (app/controllers/passwords_controller.rb:64-66): 100

#### TwoFactorAuthenticationsController

### Models

#### Application
- `needs_proof_review?` (app/models/application.rb:328-330): 50
- `valid_email?` (app/models/application.rb:222-224): 90  we should implement this
- `valid_phone?` (app/models/application.rb:218-220): 90  we should implement this

#### EmailTemplate
- `optional_variables` (app/models/email_template.rb:288-290): 80
- `render_with_tracking` (app/models/email_template.rb:226-246): 20

#### ProofReview
- `by_admin` (app/models/proof_review.rb:28): 50
- `last_3_days` (app/models/proof_review.rb:30): 50
- `recent` (app/models/proof_review.rb:27): 50
- `rejections` (app/models/proof_review.rb:29): 50

#### User
- `income_verified_applications`: 10

### Helpers

#### Admin::ApplicationsHelper
- `format_rejection_reason` (app/helpers/admin/applications_helper.rb:58-65): 50
- `format_review_status` (app/helpers/admin/applications_helper.rb:67-80): 50
- `proof_reviewer_actions_html` (app/helpers/admin/applications_helper.rb:82-118): 10

#### ActiveStorageHelper
- `safe_attachment_byte_size`: 10
- `safe_attachment_filename`: 10
- `safe_attachment_previewable?`: 100
- `safe_attachment_representation_url`: 100

#### ApplicationHelper
- `flash_class_for`: 10
- `dashboard_path_for`: 10
- `proof_status_badge`: 10
- `latest_review_and_audit`: 10

#### BadgeHelper
- `certification_status_class`: 50

#### EmailStatusHelper
- `delivery_status_badge`: 10
- `format_email_status`: 10

### Services

#### Applications::EventDeduplicationService
- `event_type_priority?` (app/services/applications/event_deduplication_service.rb:93-96): 50
- `extract_actor_name` (app/services/applications/event_deduplication_service.rb:67-75): 50

#### MedicalProviderNotifier
- `notify_certification_rejection` (app/services/medical_provider_notifier.rb:21-71): 10
- `proof_review`: 10
- `proof_review`: 10

## Summary

Total suspect LOC: 4987

**Note:** This is a static analysis and not all methods identified may truly be unused. Some might be:
- Called via reflection or metaprogramming
- Used in views or JavaScript
- Required by external gems or libraries
- Part of an API consumed externally
- Used in specific environments not reflected in the logs

Review carefully before removing any code.

**Further Analysis Note:** A deeper analysis was performed by searching the `app` directory for calls to the remaining potentially unused methods. Based on this analysis, no direct calls were found for the methods still listed above. This further supports the possibility that these methods are unused.

## Confidence Scores for Potentially Unused Methods

Here are the potentially unused methods with a confidence score (0-100) indicating the likelihood of the method being unused. A score of 0 means completely confident the method is used, and a score of 100 means completely confident the method is unused.

### Controllers

#### Admin::PoliciesController
- `set_policies`: 100

#### PasswordsController
- `password_params`: 100

### Models

#### Application
- `needs_proof_review?`: 50
- `valid_email?`: 90  we should implement this
- `valid_phone?`: 90  we should implement this

#### EmailTemplate
- `optional_variables`: 80
- `render_with_tracking`: 20

#### ProofReview
- `by_admin`: 50
- `last_3_days`: 50
- `recent`: 50
- `rejections`: 50

#### User
- `income_verified_applications`: 10

### Helpers

#### Admin::ApplicationsHelper
- `format_rejection_reason`: 50
- `format_review_status`: 50
- `proof_reviewer_actions_html`: 10

#### ActiveStorageHelper
- `safe_attachment_byte_size`: 10
- `safe_attachment_filename`: 10
- `safe_attachment_previewable?`: 100
- `safe_attachment_representation_url`: 100

#### ApplicationHelper
- `flash_class_for`: 10
- `dashboard_path_for`: 10
- `proof_status_badge`: 10
- `latest_review_and_audit`: 10

#### BadgeHelper
- `certification_status_class`: 50

#### EmailStatusHelper
- `delivery_status_badge`: 10
- `format_email_status`: 10

### Services

#### Applications::EventDeduplicationService
- `event_type_priority?` (app/services/applications/event_deduplication_service.rb:93-96): 50
- `extract_actor_name` (app/services/applications/event_deduplication_service.rb:67-75): 50

#### MedicalProviderNotifier
- `notify_certification_rejection` (app/services/medical_provider_notifier.rb:21-71): 10
- `proof_review`: 10
- `proof_review`: 10
