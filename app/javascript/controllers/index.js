import { application } from "./application"
import RoleSelectController from "./role_select_controller"
import ModalController from "./modal_controller"
import RejectionFormController from "./rejection_form_controller"
import DateInputController from "./date_input_controller"
import UploadController from "./upload_controller"
import ChartToggleController from "./chart_toggle_controller"
import ChartController from "./chart_controller"
import MobileMenuController from "./mobile_menu_controller"
import PaperApplicationController from "./paper_application_controller"
import ApplicationFormController from "./application_form_controller"
import IncomeValidationController from "./income_validation_controller"
import CurrencyFormatterController from "./currency_formatter_controller"
import DependentSelectorController from "./dependent_selector_controller"
import AccessibilityAnnouncerController from "./accessibility_announcer_controller"
import ReportsToggleController from "./reports_toggle_controller"
import ReportsChartController from "./reports_chart_controller"
import VisibilityController from "./visibility_controller"
import DateRangeController from "./date_range_controller"
import W9ReviewController from "./w9_review_controller"
import PdfLoaderController from "./pdf_loader_controller"
import EvaluationManagementController from "./evaluation_management_controller"
import CheckboxSelectAllController from "./checkbox_select_all_controller"
import AddCredentialController from "./add_credential_controller"
import CredentialAuthenticatorController from "./credential_authenticator_controller"
import TotpFormController from "./totp_form_controller"
import AdminUserSearchController from "./admin_user_search_controller"
import DependentFieldsController from "./dependent_fields_controller"
import ApplicantTypeController from "./applicant_type_controller"
import DocumentProofHandlerController from "./document_proof_handler_controller"
// import GuardianSelectionController from "./guardian_selection_controller"
import GuardianPickerController from "./guardian_picker_controller"
import FormValidationController from "./form_validation_controller"

// Development-only imports
if (process.env?.NODE_ENV === "development") {
  import("./debug_controller").then(module => {
    application.register("debug", module.default)
  })
}

application.register("role-select", RoleSelectController)
application.register("modal", ModalController)
application.register("rejection-form", RejectionFormController)
application.register("date-input", DateInputController)
application.register("upload", UploadController)
application.register("chart-toggle", ChartToggleController)
application.register("chart", ChartController)
application.register("mobile-menu", MobileMenuController)
application.register("paper-application", PaperApplicationController)
application.register("application-form", ApplicationFormController)
application.register("income-validation", IncomeValidationController)
application.register("currency-formatter", CurrencyFormatterController)
application.register("dependent-selector", DependentSelectorController)
application.register("accessibility-announcer", AccessibilityAnnouncerController)
application.register("reports-toggle", ReportsToggleController)
application.register("reports-chart", ReportsChartController)
application.register("visibility", VisibilityController)
application.register("date-range", DateRangeController)
application.register("w9-review", W9ReviewController)
application.register("pdf-loader", PdfLoaderController)
application.register("evaluation-management", EvaluationManagementController)
application.register("checkbox-select-all", CheckboxSelectAllController)
application.register("add-credential", AddCredentialController)
application.register("credential-authenticator", CredentialAuthenticatorController)
application.register("totp-form", TotpFormController)
application.register("admin-user-search", AdminUserSearchController)
application.register("dependent-fields", DependentFieldsController)
application.register("applicant-type", ApplicantTypeController)
application.register("document-proof-handler", DocumentProofHandlerController)
application.register("guardian-picker", GuardianPickerController)
// application.register("guardian-selection", GuardianSelectionController)
application.register("form-validation", FormValidationController)
