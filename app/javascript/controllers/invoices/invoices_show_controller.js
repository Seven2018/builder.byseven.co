import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static get targets () {
    return ['objectDisplay', 'objectForm', 'objectInput', 'objectSubmit']
  }

  toggleEditObject() {
    this.objectDisplayTarget.classList.toggle('hidden')
    this.objectFormTarget.classList.toggle('hidden')
  }

  confirmObject() {
    this.objectDisplayTarget.querySelector('p').innerHTML = 'Object : ' + this.objectInputTarget.value
    this.objectSubmitTarget.click()

    this.toggleEditObject()
  }

  enableInvoiceEdit(event) {
    const element = event.currentTarget
    const form = element.closest('form')
    const button = form.querySelector('button[type="submit"]')

    if (element.value != '') {
      button.disabled = false
      button.classList.remove('disabled')
    } else {
      button.disabled = true
      button.classList.add('disabled')
    }
  }

  disableInvoiceEdit(event) {
    const element = event.currentTarget
    const form = element.closest('form')
    const button = form.querySelector('button[type="submit"]')

    button.disabled = true
    button.classList.add('disabled')
  }
}