import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static get targets () {
    return ['tabContainer']
  }

  selectTab() {
    const container = this.tabContainerTarget
    const selected_tab = event.currentTarget.id

    container.querySelector('.bld-tab-control.active').classList.remove('active')
    container.querySelectorAll('.bld-tab').forEach((tab) => { tab.classList.add('hidden') })

    event.currentTarget.classList.add('active')
    container.querySelector('#' + selected_tab + '-display').classList.remove('hidden')
  }
}
