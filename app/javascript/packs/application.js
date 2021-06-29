import "bootstrap";
require("../plugins/flatpickr")
require("../plugins/handsontable")

try {
  require("trix")
  require("@rails/actiontext")
}
catch(err) {
}
