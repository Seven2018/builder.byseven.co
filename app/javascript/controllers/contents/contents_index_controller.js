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


  ////////////
  // SEARCH //
  ////////////

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
}
