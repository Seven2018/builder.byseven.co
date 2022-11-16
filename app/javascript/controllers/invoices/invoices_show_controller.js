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
}