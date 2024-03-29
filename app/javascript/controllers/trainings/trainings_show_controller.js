import { Controller } from '@hotwired/stimulus'
import { useClickOutside } from 'stimulus-use'

export default class extends Controller {
  static get targets () {
    return ['calendarButton']
  }

  connect() {
    this.element[
      (str => {
        return str
          .split('--')
          .slice(-1)[0]
          .split(/[-_]/)
          .map(w => w.replace(/./, m => m.toUpperCase()))
          .join('')
          .replace(/^\w/, c => c.toLowerCase())
      })(this.identifier)
      ] = this

    this.setup()
    useClickOutside(this, { element: document.querySelector('.dropdown-pdf') })
  }

  setup() {
    flatpickr(".datepicker", {
      disableMobile: true,
      dateFormat: "d/m/Y",});

    const timepicker24s = document.querySelectorAll('.timepicker_24')
    timepicker24s.forEach((element) => {
      flatpickr(element, {
        enableTime: true,
        noCalendar: true,
        dateFormat: "H:i",
        time_24hr: true,
        minuteIncrement: 5,
        defaultDate: element.dataset.defaultTime
      })
    })

    this.enableCalendarUpdate()
  }


  ///////////////////////
  // OPEN SESSION EDIT //
  ///////////////////////

  openSessionForm(event) {
    const element = event.currentTarget
    const card = element.closest('.card-lg')
    card.querySelector('.card-footer-lg__infos').classList.add('hidden')
    card.querySelector('.card-session-header').querySelector('h3').classList.add('hidden')
    card.querySelector('.sessions-copy').classList.add('hidden')
    card.querySelector('#owner-session-index').classList.add('hidden')
    card.querySelector('.card-footer-lg__form').classList.remove('hidden')
    card.querySelector('.card-main-lg').setAttribute('ondblclick','writeLED(1,1)')
  }


  ////////////////
  // EXPORT PDF //
  ////////////////

  openExportSubMenu(event) {
    const element = event.currentTarget
    const dropdown_pdf = element.parentNode.parentNode.querySelector('.dropdown-pdf')
    dropdown_pdf.classList.remove('hidden')
  }

  closeExportSubMenu(event) {
    const element = event.currentTarget
    const dropdown_pdf = element.parentNode.parentNode.querySelector('.dropdown-pdf')
    dropdown_pdf.classList.add('hidden')
  }


  /////////////////////
  // CALENDAR UPDATE //
  /////////////////////

  enableCalendarUpdate() {
    if (!this.hasCalendarButtonTarget) return false 

    if (this.element.querySelector('.timing_error') != undefined) {
      this.calendarButtonTarget.classList.add('disabled')
      this.calendarButtonTarget.removeAttribute("href")
    } else {
      this.calendarButtonTarget.classList.remove('disabled')
      this.calendarButtonTarget.href = this.calendarButtonTarget.dataset.link
    }
  }


  ////////////////////////
  // TRAINER MANAGEMENT //
  ////////////////////////

  selectTrainer(event) {
    const element = event.currentTarget
    const add_button = element.closest('.modal').querySelector('#add-button')
    const trainer_id = element.dataset.value

    add_button.dataset.trainerId = trainer_id
  }

  addTrainer(event) {
    const element = event.currentTarget
    const trainer_id = element.dataset.trainerId

    document.querySelector('body').classList.add('wait')
    this.updateSingleTrainer(element, trainer_id)
    this.resetSelectTrainer(element)
  }

  removeTrainer(event) {
    const element = event.currentTarget
    const fullname = element.parentNode.querySelector('p').innerText
    const modal = element.closest('.modal')
    const message = modal.querySelector('.modal-message')
    const confirm = message.querySelector('.confirm_remove')

    message.querySelector('span').innerText = fullname
    message.classList.toggle('d-none')
    message.classList.toggle('d-flex')
    confirm.dataset.userId = element.parentNode.id.split('-')[1]
  }

  cancelRemove(event) {
    const element = event.currentTarget
    const modal = element.closest('.modal')
    const message = modal.querySelector('.modal-message')

    message.classList.toggle('d-none')
    message.classList.toggle('d-flex')
  }

  confirmRemoveTrainer(event) {
    const element = event.currentTarget
    const modal = element.closest('.modal')
    const user_id = element.dataset.userId
    const link = modal.querySelector(`.remove_link-${user_id}`)

    link.click()
    document.querySelector('body').classList.add('wait')
  }


  /////////////
  // PRIVATE //
  /////////////

  updateSingleTrainer(element, trainer_id) {
    const form = element.closest('.modal-body').querySelector('form')
    const selected_storage = form.querySelector('#link_trainer_id')

    selected_storage.value = trainer_id
    form.querySelector('.hidden-submit').click()
  }

  resetSelectTrainer(element) {
    const select_container = element.closest('.modal').querySelector('.bld-select-container')
    const select_display = select_container.querySelector('input')
    const select_storage = select_container.querySelector('input[type="hidden"]')

    select_display.value = ''
    select_storage.value = ''
  }
}
