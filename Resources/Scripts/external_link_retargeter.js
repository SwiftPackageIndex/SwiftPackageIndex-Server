export class ExternalLinkRetargeter {
  constructor() {
    document.addEventListener('click', (event) => {
      const externalLinkElement = event.target.findParentMatching((element) => {
        return (
          element.nodeName.toLowerCase() == 'a' &&
          element.hostname != window.location.hostname
        )
      })

      if (externalLinkElement)
        externalLinkElement.setAttribute('target', '_blank')
    })
  }
}
