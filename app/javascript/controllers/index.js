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
import ReportsToggleController from "./reports_toggle_controller"
import ReportsChartController from "./reports_chart_controller"
import VisibilityController from "./visibility_controller"
import DateRangeController from "./date_range_controller"
import W9ReviewController from "./w9_review_controller"
import PdfLoaderController from "./pdf_loader_controller"
import EvaluationManagementController from "./evaluation_management_controller"
import CommunicationPreferenceController from "./communication_preference_controller"
import CheckboxSelectAllController from "./checkbox_select_all_controller"

application.register("role-select", RoleSelectController)
application.register("modal", ModalController)
application.register("rejection-form", RejectionFormController)
application.register("dateinput", DateInputController)
application.register("upload", UploadController)
application.register("chart-toggle", ChartToggleController)
application.register("chart", ChartController)
application.register("mobile-menu", MobileMenuController)
application.register("paper-application", PaperApplicationController)
application.register("application-form", ApplicationFormController)
application.register("reports-toggle", ReportsToggleController)
application.register("reports-chart", ReportsChartController)
application.register("visibility", VisibilityController)
application.register("date-range", DateRangeController)
application.register("w9-review", W9ReviewController)
application.register("pdf-loader", PdfLoaderController)
application.register("evaluation-management", EvaluationManagementController)
application.register("communication-preference", CommunicationPreferenceController)
application.register("checkbox-select-all", CheckboxSelectAllController)
