import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static get targets () {
    return ['display']
  }

  show() {
    this.element.dataset.side == 'right' ? this.displayTarget.style.right = '0' : this.displayTarget.style.left = '0'
  }

  hide() {
    if (this.displayTarget.dataset.resetSide = 'right') {
      this.displayTarget.style.right = '-' + this.element.dataset.offsetValue
    } else {
      this.displayTarget.style.left = '-' +this.element.dataset.offsetValue
    }
  }
}
