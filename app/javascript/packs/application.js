import "bootstrap"
import 'controllers'
require("../plugins/flatpickr")

try {
  require("trix")
  require("@rails/actiontext")
}
catch(err) {
}
