export class SPITurbolinkForms {
  constructor() {
    // Bind to ALL submit events, regardless of where they come from.
    document.addEventListener('submit', (event) => {
      // Submit forms that use GET requests using Turbolinks.
      const formElement = event.target
      if (formElement.matches('form') && formElement.method === 'get') {
        // Construct the URL for this form submission in a generic way.
        const formData = new FormData(formElement)
        const params = new URLSearchParams(formData)
        const url = new URL(formElement.action)
        url.search = params.toString()

        // We need to clear the Turbolinks cache here as by default it will restore any
        // previous value of the query field (from the last page load) before replacing
        // it with the new value. This causes a flickering effect in the content of the
        // query field.
        window.Turbolinks.clearCache()

        // Instead of submitting the form, navigate to the constructed URL.
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
