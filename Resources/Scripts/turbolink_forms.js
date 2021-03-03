import Turbolinks from 'turbolinks'

export class SPITurbolinkForms {
  constructor() {
    // Bind to ALL submit events, regardless of where they come from.
    document.addEventListener('submit', (event) => {
      // Submit forms that use GET requests using Turbolinks.
      const formElement = event.target
      if (formElement.matches('form') && formElement.method === 'get') {
        const formData = new FormData(formElement)
        const params = new URLSearchParams(formData)
        const url = new URL(formElement.action)
        url.search = params.toString()
        Turbolinks.visit(url.toString())

        // Stop the form submission.
        event.preventDefault()
      }
    })
  }
}
