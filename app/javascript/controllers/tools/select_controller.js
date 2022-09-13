import { useClickOutside } from 'stimulus-use'
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static get targets () {
    return [ "menu", "display", 'overlay' ]
  }

  connect() {
    useClickOutside(this)
  }

  toggle () {
    this.menuTarget.classList.toggle('hidden')
    if (this.hasOverlayTarget) {this.overlayTarget.classList.remove('hidden')}
  }

  hide () {
    this.menuTarget.classList.add('hidden')
    if (this.hasOverlayTarget) {this.overlayTarget.classList.add('hidden')}
  }

  selectOption(e) {
    const selected_display = this.displayTarget
    const selected_option = e.currentTarget
    const selected_value = this.element.querySelector("input[type='hidden']")

    if (selected_value) {selected_value.value = selected_option.getAttribute('data-value')}
    selected_display.innerText = selected_option.innerText
    selected_display.classList.add('bkt-dark-grey')

    this.hide()
  }

  //////////
  // MISC //
  //////////

  changeColor(event) {
    const element = event.currentTarget

    element.parentNode.querySelectorAll('div').forEach((div) => {
      div.classList.remove('bkt-blue-important')
    })

    element.classList.add('bkt-blue-important')
  }

  clickOutside(event) {
    this.hide()
  }
}
