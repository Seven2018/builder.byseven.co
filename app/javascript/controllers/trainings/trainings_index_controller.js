import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static get targets () {
    return ['']
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

    console.log('coucou')
  }
}
