import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static get targets () {
    return ['checkbox', 'selectedStorage']
  }

  check(event) {
    const element = event.currentTarget
    this.checkBox(element)

    this.updateStorage()
  }

  checkAll(event) {
    const element = event.currentTarget
    const status = this.checkBox(element).checked

    this.checkboxTargets.forEach((checkbox) => {
      this.checkBox(checkbox.closest('label'), status)
    })

    this.updateStorage()
  }

  updateStorage() {
    if (this.hasSelectedStorageTarget) {
      this.selectedStorageTarget.value = this.checkboxTargets.filter(x => x.checked).map(y => y.id)
    }
  }


  /////////////
  // PRIVATE //
  /////////////

  checkBox(element, force = null) {
    const input = element.querySelector('input')
    const svg = element.querySelector('svg')
    force ? input.checked = force : input.checked = !input.checked

    input.checked ? svg.classList.remove('hidden') : svg.classList.add('hidden')

    return input
  }
}
