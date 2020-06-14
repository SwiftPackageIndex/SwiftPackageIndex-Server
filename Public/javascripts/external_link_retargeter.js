export class ExternalLinkRetargeter {
  constructor() {
    document.addEventListener('DOMContentLoaded', () => {
      this.installDocumentEventHandlers()
    })
  }

  installDocumentEventHandlers() {
    document.addEventListener('click', (event) => {
      const clickedElement = event.target
      const matchingElement = clickedElement.findParentMatching((element) => {
        return element.nodeName.toLowerCase() == 'a' && element.hostname != window.location.hostname
      })

      if (matchingElement) {
        matchingElement.setAttribute('target', '_blank')
      }
    })
  }
}
