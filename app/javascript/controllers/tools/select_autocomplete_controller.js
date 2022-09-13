import { useClickOutside } from 'stimulus-use'
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static get targets () {
    return [ "menu", "input", "hiddenInput", "resultElement" ]
  }

  connect() {
    this.timer
    this.waitTime = 200
    this.selected = true

    useClickOutside(this)
    this.search(null, this.hiddenInputTarget.value == '')
  }

  toggle () {
    this.menuTarget.classList.toggle('hidden')
  }

  hide () {
    this.menuTarget.classList.add('hidden')
  }

  search(event = null, selected_value_absent = true) {
    if (event && event.type == 'keyup' && this.selected && [8,46].includes(event.keyCode)) {
      event.preventDefault
      this.inputTarget.value = ''
      this.hiddenInputTarget.value = ''
      this.selected = false
    } else if (event && event.type == 'keyup') {
      this.selected = false
    }

    clearTimeout(this.timer);
    const query = this.selected ? '' : this.inputTarget.value

    this.timer = setTimeout(() => {
      const path = this.element.dataset.path
      const additional_params = this.element.dataset.additionalParams
      const url = `${path}?search=${query}&${additional_params}`
      const selected_value = this.element.querySelector("input[type='hidden']")

      if (query == '' && selected_value_absent) {
        this.hiddenInputTarget.value = ''
      }

      fetch(url)
        .then(response => response.text())
        .then(html => {
          this.menuTarget.innerHTML = html
          this.resultElementTargets.forEach((result) => {
            result.dataset.action += ' ' + this.menuTarget.dataset.elementAction
          })
        })

    }, this.waitTime);
  }

  selectOption(e) {
    const selected_input = this.inputTarget
    const selected_option = e.currentTarget

    this.hiddenInputTarget.value = selected_option.getAttribute('data-value')
    selected_input.value = selected_option.innerText

    this.selected = true
    this.search(null, false)
    this.hide()
  }

  //////////
  // MISC //
  //////////

  clickOutside(event) {
    this.hide()
  }
}
