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

    this.timer
    this.waitTime = 500
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
  // LIBRARY //
  /////////////

  showLibrary(open) {
    const library = document.getElementById('library');

    library.style.height = '100%';
  }

  hideLibrary(open) {
    const library = document.getElementById('library');

    library.style.height = '0px';
  }

  searchSubmit(event) {
    const element = event.currentTarget
    const form = element.closest('form')
    const submit = form.querySelector('.hidden-submit')

    clearTimeout(this.timer);

    this.timer = setTimeout(() => {
      submit.click()
      document.querySelector('body').classList.add('wait')
    }, this.waitTime);
  }

  toggleContentList(event) {
    const element = event.currentTarget
    const container = element.parentNode
    const caret = container.querySelector('svg')
    const list = container.querySelector('.content-list')

    if (container.offsetHeight == '40') {
      container.style.maxHeight = '10000000000rem'
      list.style.maxHeight = '10000000000rem'
      list.classList.add('active')
      caret.dataset.rotate = '90deg'
    } else {
      container.style.maxHeight = '4rem'
      list.style.maxHeight = '0'
      list.classList.remove('active')
      caret.dataset.rotate = '0'
    }
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
