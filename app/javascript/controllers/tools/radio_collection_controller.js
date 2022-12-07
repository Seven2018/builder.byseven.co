import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static get targets () {
    return ["customRadio"]
  }

  connect() {
    this.setup()
  }

  setup() {
    const checked = this.element.dataset.checked

    if (checked == '') return false

    this.element.querySelector(`#${checked}`).checked = true

    this.updateRadios()
  }

  selectRadio(event) {
    const element = event.currentTarget
    const input = element.querySelector('input')
    
    input.checked = true

    this.updateRadios()
  }


  /////////////
  // PRIVATE //
  /////////////

  updateRadios() {
    const color = this.element.dataset.color

    this.customRadioTargets.forEach((container) => {
      const radio = container.querySelector('div')

      if (radio.querySelector('input').checked) {
        radio.classList.add(`bld-bg-${color}`, `border-bld-${color}`)
      } else {
        radio.classList.remove(`bld-bg-${color}`, `border-bld-${color}`)
      }
    })
  }
}
