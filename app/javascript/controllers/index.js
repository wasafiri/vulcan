import { application } from "./application"
import RoleSelectController from "./role_select_controller"
import ModalController from "./modal_controller"
import RejectionFormController from "./rejection_form_controller"
import DateInputController from "./date_input_controller"
import UploadController from "./upload_controller"

application.register("role-select", RoleSelectController)
application.register("modal", ModalController)
application.register("rejection-form", RejectionFormController)
application.register("dateinput", DateInputController)
application.register("upload", UploadController)
