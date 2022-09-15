import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static get targets () {
    return []
  }

  connect() {
    const timepicker24s = document.querySelectorAll('.timepicker_24')
    timepicker24s.forEach((element) => {
      flatpickr(element, {
        enableTime: true,
        noCalendar: true,
        dateFormat: "H:i",
        time_24hr: true,
        defaultDate: element.dataset.defaultTime
      })
    })
  }

  selectTrainer(event) {
    const element = event.currentTarget
    const add_button = element.closest('.modal').querySelector('#add-button')
    const trainer_id = element.dataset.value

    add_button.dataset.trainerId = trainer_id
    add_button.dataset.trainerFullname = element.innerText
  }

  addTrainer(event) {
    const element = event.currentTarget
    const trainer_id = element.dataset.trainerId
    const trainer_fullname = element.dataset.trainerFullname
    const pill_container = element.closest('.modal-body').querySelector('.users-list-details')

    const new_pill = document.createElement('div')

    new_pill.classList.add('trainer-pill')
    new_pill.id = 'user-' + trainer_id
    new_pill.innerHTML = "<p>" + trainer_fullname + "</p><i class='fas fa-times' onclick='selectTrainer(this, false);'></i>"
    pill_container.appendChild(new_pill)

    this.updateTrainerList(pill_container)
  }

  removeTrainer(event) {
    const element = event.currentTarget
    const pill_container = element.closest('.modal-body').querySelector('.users-list-details')

    element.closest('.trainer-pill').remove()

    this.updateTrainerList(pill_container)
  }

  confirmTrainers(event) {
    const element = event.currentTarget
    const form = element.parentNode.querySelector('form')
    const confirm_button = form.querySelector('.hidden-submit')
    const modal = element.closest('.modal')

    modal.querySelector('.btn-icon-close').click()
    confirm_button.click()
    document.querySelector('body').classList.add('wait')
  }


  /////////////
  // PRIVATE //
  /////////////

  updateTrainerList(pill_container) {
    var selected_array = []
    const form = pill_container.closest('.modal-body').querySelector('form')
    const selected_storage = form.querySelector('#link_trainer_ids')

    pill_container.querySelectorAll('.trainer-pill').forEach((pill) =>{
      if (pill.id != '') {
        selected_array.push(pill.id.split('-')[1])
      }
    })
    selected_storage.value = selected_array
  }
}
