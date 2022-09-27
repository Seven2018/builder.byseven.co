import { Controller } from "@hotwired/stimulus"


export default class extends Controller {
  static get targets () {
    return [ "search", "dropdown", "submit" ]
  }
  static get values () {
    return {
      key: String
    }
  }

  connect() {
    // if (this.hasSearchTarget && this.hasSubmitTarget) {
    //   if (this.currentSearch()) {
    //     this.searchTarget.value = this.currentSearch()
    //     this.submitTarget.click()
    //   }
    // }

    const params = new Proxy(new URLSearchParams(window.location.search), {
      get: (searchParams, prop) => searchParams.get(prop),
    });

    if (params.back_search_text) {
      this.searchTarget.value = params.back_search_text
    }

    this.setupHrefs()
  }

  setupHrefs() {
    let el = document.querySelectorAll('.setup-search-arg')

    if (el) {
      el.forEach(a => {
        const text = localStorage.getItem(this.keyValue)

        if (text) {
          a.href = `${window.location.pathname}?back_search_text=${text}`
        }
      })
      localStorage.setItem(this.keyValue, '')
    }
  }

  storeSearch() {
    const searchbar = document.getElementById('searchbar');

    if (searchbar.querySelector('#search_page'))
      searchbar.querySelector('#search_page').value = '1'

    window.localStorage.setItem(this.keyValue, this.searchTarget.value)
  }

  currentSearch () {
    return window.localStorage.getItem(this.keyValue) || false
  }

  resetAllFilter(_) {
    const searchbar = document.getElementById('searchbar');
    const dropdowns = this.dropdownTargets

    // Reset Search and Period input
    searchbar.querySelectorAll('input').forEach((input) => {
      if (input.type == 'text') {
        input.value = ''
      } else if (input.type == 'checkbox') {
        input.checked = false
      }
    })

    try {
      searchbar.querySelectorAll('select').forEach((select) => {
        select.selectedIndex = 0
      })
    } catch {}

    // try {
      searchbar.querySelectorAll('.bkt-select-container').forEach((select) => {
        const placeholder = select.querySelector('.bkt-select-display').firstElementChild

        if (select.dataset.placeHolder) {
          select.querySelector('input').value = ''
          placeholder.classList.remove('bkt-dark-grey')
          placeholder.innerText = select.dataset.placeHolder
        } else {
          const first_element = select.querySelector('.bkt-select-menu').firstElementChild

          select.querySelector('input').value = first_element.value
          placeholder.innerText = first_element.innerText
        }

      })
    // } catch {}

    // Reset custom dropdowns
    dropdowns.forEach((dropdown) => {
      const ps = dropdown.querySelectorAll('p')
      const display_container = ps[0]
      const default_value = ps[1]
      const value_storage = dropdown.querySelector("input[type='hidden']")

      display_container.innerText = default_value.innerText
      value_storage.value = default_value.dataset.value
    })

    // TODO : Unify all searches by tags
    try {
      // Reset Tags
      const pill_container = searchbar.querySelector('#displayed-tags')
      const default_color = searchbar.dataset.color
      const default_background_color = searchbar.dataset.backgroundColor

      searchbar.querySelector('#search_tags').value = ''

      pill_container.querySelectorAll('.tag-pill').forEach((pill) => {
        pill.querySelector('input').checked = false
        pill.classList.remove(default_color, default_background_color)
        pill.classList.add('bkt-dark-grey', 'bkt-bg-light-grey8')
      })
    } catch {}

    try {
      // Reset offset
      searchbar.querySelector('#search_page').value = '1'

      searchbar.querySelector('.btn-search').click()
      document.querySelector('body').classList.add('wait')
      window.localStorage.setItem(this.keyValue, '')
    } catch {}

    this.setupHrefs()

    this.submitTarget.click()
  }
}
