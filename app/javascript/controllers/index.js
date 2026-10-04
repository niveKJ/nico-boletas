import { Application } from "@hotwired/stimulus"
import UploadController from "controllers/upload_controller"

const application = Application.start()
application.debug = false
window.Stimulus = application

application.register("upload", UploadController)