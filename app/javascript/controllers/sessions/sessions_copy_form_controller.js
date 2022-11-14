import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static get targets () {
    return ['sessionsList']
  }

  switchConfirmButton() {
    const input = document.querySelector('[name="copy[target_training_id]"]');
    const button_copy = document.querySelector('.copy-button');
    const button_copy_here = document.querySelector('.copy-here-button');

    if (input.value != "") {
      button_copy.classList.remove('hidden');
      button_copy_here.classList.add('hidden');
    } else if (input.value == "") {
      button_copy.classList.add('hidden');
      button_copy_here.classList.remove('hidden');
    }
  }

  fetchSessions(event) {
    if (event.type == 'keyup') {
      this.sessionsListTarget.innerHTML = ''
    } else {
      const element = event.currentTarget
      const target_id = element.dataset.value

      const url = `/training_sessions_list?training_id=${target_id}&empty=false`

      fetch(url)
        .then(response => response.text())
        .then(html => {
          this.sessionsListTarget.innerHTML = html
        })
    }
  }


  ///////////
  // TOOLS //
  ///////////

  blockEvents() {
    document.getElementById('bld-blockDiv').classList.toggle('d-none')
    document.querySelector('body').classList.toggle('wait')
  }
}
