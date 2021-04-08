export class SPIAutofocus {
  constructor() {
    document.addEventListener('turbo:load', () => {
      // Find any elements with data-autofocus set to 'true' and focus them.
      const autofocusElement = document.querySelector('[data-autofocus="true"]')
      if (autofocusElement) autofocusElement.focus()
    })
  }
}
