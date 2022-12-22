import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static get targets () {
    return ['newPassword', 'confirmPassword']
  }

  checkPasswordMatch() {
    const newP = this.newPasswordTarget.value
    const confirmP = this.confirmPasswordTarget.value
    const button = this.element.querySelector('button[type="submit"]')

    if (confirmP === newP) {
      console.log('match')
      button.classList.remove('disabled')
      button.disabled = false
    } else {
      console.log('not match')
      button.classList.add('disabled')
      button.disabled = true
    }
  }
}
