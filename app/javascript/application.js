// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import * as ActiveStorage from "@rails/activestorage"
import "./controllers"

ActiveStorage.start()
