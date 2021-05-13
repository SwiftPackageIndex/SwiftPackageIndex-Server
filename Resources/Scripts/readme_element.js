export class SPIReadmeElement extends HTMLElement {
  constructor() {
    super()

    const linkElements = this.querySelectorAll('a')
    linkElements.forEach((linkElement) => {
      // Remove turbo from *all* links inside the README.
      linkElement.setAttribute('data-turbo', 'false')

      const linkTarget = linkElement.getAttribute('href')
      if (linkTarget.charAt(0) === '#') {
        // Fix up anchor URLs by faking the navigation.
        linkElement.addEventListener('click', (event) => {
          const targetAnchor = `user-content-${linkTarget.substring(1)}`
          const destinationElement = document.getElementById(targetAnchor)
          if (destinationElement) destinationElement.scrollIntoView()
          event.preventDefault()
        })
      }
    })
  }
}
