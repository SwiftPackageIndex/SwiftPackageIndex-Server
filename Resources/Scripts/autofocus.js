export class SPIAutofocus {
  constructor() {
    document.addEventListener('turbo:load', () => {
      // Find any elements with data-focus set to 'true' and focus them.
      const autofocusElement = document.querySelector('[data-focus="true"]')
      if (autofocusElement) autofocusElement.focus()
    })
  }
}
