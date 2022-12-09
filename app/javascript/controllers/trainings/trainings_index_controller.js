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

    this.clickGuardian = false

    this.setupHorizontalScroll()
  }

  showTab(event) {
    const element = event.currentTarget
    const tabs = document.querySelectorAll('[data-tab]')
    const target_tab = element.dataset.tab

    if (!this.clickGuardian) {
      this.clickGuardian = true

      tabs.forEach((tab) => {
        var tab_data = tab.dataset.tab

        if (tab_data == target_tab) {
          tab.classList.add('active')
          document.querySelector(`[data-tab-container="${tab_data}"]`).classList.remove('hidden')
        } else {
          tab.classList.remove('active')
          document.querySelector(`[data-tab-container="${tab_data}"]`).classList.add('hidden')
        }
      })

      setTimeout(() => {this.clickGuardian = false}, 100)
    }

  }


  /////////////
  // PRIVATE //
  /////////////

  setupHorizontalScroll() {
    const sliders = document.querySelectorAll('.trainings-row');

    sliders.forEach((slider) => {
      var isDown = false;
      var startX;
      var scrollLeft;

      slider.addEventListener('mousedown', (e) => {
        isDown = true;
        slider.classList.add('active');
        startX = e.pageX - slider.offsetLeft;
        scrollLeft = slider.scrollLeft;
      });
      slider.addEventListener('mouseleave', () => {
        isDown = false;
        slider.classList.remove('active');
      });
      slider.addEventListener('mouseup', () => {
        isDown = false;
        slider.classList.remove('active');
      });
      slider.addEventListener('mousemove', (e) => {
        if(!isDown) return;
        e.preventDefault();
        const x = e.pageX - slider.offsetLeft;
        const walk = (x - startX) * 3; //scroll-fast
        slider.scrollLeft = scrollLeft - walk;
      });
    })
  }

}
