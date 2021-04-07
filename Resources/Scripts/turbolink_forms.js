export class SPITurbolinkForms {
  constructor() {
    // Bind to ALL submit events, regardless of where they come from.
    document.addEventListener('submit', (event) => {
      // Submit forms that use GET requests using Turbo.
      const formElement = event.target
      if (formElement.matches('form') && formElement.method === 'get') {
        // Construct the URL for this form submission in a generic way.
        const formData = new FormData(formElement)
        const params = new URLSearchParams(formData)
        const url = new URL(formElement.action)
        url.search = params.toString()

        // We need to clear the Turbo cache here as by default it will restore any previous
        // value of the query field (from the last page load) before replacing it with the
        // new value. This causes a flickering effect in the content of the query field.
        window.Turbo.clearCache()

        // Instead of submitting the form, navigate to the constructed URL.
        window.Turbo.visit(url.toString())
        event.preventDefault()
      }
    })
  }
}
