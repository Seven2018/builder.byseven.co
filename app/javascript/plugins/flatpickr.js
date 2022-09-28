// app/javascript/plugins/flatpickr.js
import flatpickr from "flatpickr"
import "flatpickr/dist/flatpickr.min.css" // Note this is important!
// require("flatpickr/dist/flatpickr.css")

flatpickr(".datepicker", {
  disableMobile: true,
  dateFormat: "d/m/Y",
})

// flatpickr(".timepicker", {
//   enableTime: true,
//   noCalendar: true,
//   dateFormat: "H:i",
// })

// const timepicker24s = document.querySelectorAll('.timepicker_24')
// timepicker24s.forEach((element) => {
//   flatpickr(element, {
//     enableTime: true,
//     noCalendar: true,
//     dateFormat: "H:i",
//     time_24hr: true,
//     defaultDate: element.dataset.defaultTime
//   })
// })
