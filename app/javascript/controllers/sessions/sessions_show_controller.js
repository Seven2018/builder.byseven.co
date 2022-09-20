import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static get targets () {
    return []
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

  removeTrainer() {
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
