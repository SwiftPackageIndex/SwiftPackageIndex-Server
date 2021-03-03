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

        // Stop the form submission.
        window.Turbolinks.visit(url.toString())
        event.preventDefault()
      }
    })
  }
}

HTMLDocument.prototype.addTurbolinksEventListener = function (
  event,
  listenerFunction
) {
  console.log('binding')
  const unbindListenerFunction = function () {
    document.removeEventListener(event, listenerFunction)
    document.removeEventListener(
      'turbolinks:before-visit',
      unbindListenerFunction
    )
    console.log('unbinding')
  }

  document.addEventListener(event, listenerFunction)
  document.addEventListener('turbolinks:before-visit', unbindListenerFunction)
}
