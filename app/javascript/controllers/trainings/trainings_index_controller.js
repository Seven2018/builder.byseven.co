import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static get targets () {
    return ['upcomingContainer', 'completedContainer']
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
    this.waitTime = 500
    this.timer

    this.setCompleted()
    this.setupHorizontalScroll()
  }


  ////////////
  // SEARCH //
  ////////////

  search() {
    clearTimeout(this.timer);

    this.timer = setTimeout(() => {
      const form = document.getElementById('search-form')
      const submit = form.querySelector('.hidden-submit')

      submit.click()
      this.displaySpinner(this.upcomingContainerTarget)

      this.setCompleted()

    }, this.waitTime)
  }


  //////////
  // TABS //
  //////////

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

  setCompleted() {
    this.displaySpinner(this.completedContainerTarget)

    const search_title = document.getElementById('search_title').value
    const additional_params = window.location.search.substring(1)
    const path = '/trainings_completed'
    const url = `${path}?search[title]=${search_title}&${additional_params}`

    fetch(url)
      .then(response => response.text())
      .then(html => {
        this.completedContainerTarget.innerHTML = html
      })
  }

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

  displaySpinner(node) {
    node.innerHTML = '<div class="height-29rem d-flex flex-column justify-content-center align-items-center" style="width: calc(100vw - 8rem);"><p class="bld-yellow fs-1_6rem font-weight-700 mb-2rem">Loading...</p><div class="loader-yellow"></div></div>'
  }

}
