import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static get targets () {
    return ['form']
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
}
