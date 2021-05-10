export class SPIAutofocus {
  constructor() {
    document.addEventListener('turbo:load', () => {
      // Find any elements with data-focus set to 'true' and focus them.
      // Note: This previously used data-autofocus, but as of Safari 14.1
      // that started grabbing focus using the standard autofocus rules.
      const autofocusElement = document.querySelector('[data-focus="true"]')
      if (autofocusElement) autofocusElement.focus()
    })
  }
}
