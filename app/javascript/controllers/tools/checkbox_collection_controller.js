import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static get targets () {
    return ['checkbox', 'selectedStorage']
  }

  check(event) {
    const element = event.currentTarget
    const input = element.querySelector('input')
    const svg = element.querySelector('svg')
    input.checked = !input.checked

    input.checked ? svg.classList.remove('hidden') : svg.classList.add('hidden')

    if (this.hasSelectedStorageTarget) {
      this.updateStorage()
    }
  }

  updateStorage() {
    this.selectedStorageTarget.value = this.checkboxTargets.filter(x => x.checked).map(y => y.id)
  }
}
