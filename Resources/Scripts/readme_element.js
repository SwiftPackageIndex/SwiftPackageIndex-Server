export class SPIReadmeElement extends HTMLElement {
  constructor() {
    super()

    // -----------------------------------------------------------------------------------
    // Note: This is very brittle code that relies on everything being hosted with GitHub.
    // -----------------------------------------------------------------------------------

    // Find all relative image URLs and point them at the raw image sources.
    const readmeImages = this.querySelectorAll('img')
    readmeImages.forEach((imageElement) => {
      const imageSource = imageElement.getAttribute('src')
      try {
        // Relative URLs will *fail* this initialisation.
        new URL(imageSource)
      } catch (error) {
        imageElement.src = `https://github.com${imageSource}`
      }
    })

    // Fix up relative and anchor URLs.
    const links = this.querySelectorAll('a')
    links.forEach((linkElement) => {
      // Remove turbo from *all* links inside the readme.
      linkElement.setAttribute('data-turbo', 'false')

      const linkTarget = linkElement.getAttribute('href')
      if (linkTarget.charAt(0) === '#') {
        // Fix up anchor URLs by faking the navigation.
        linkElement.addEventListener('click', (event) => {
          const targetAnchor = `user-content-${linkTarget.substring(1)}`
          const destinationElement = document.getElementById(targetAnchor)
          destinationElement.scrollIntoView()
          event.preventDefault()
        })
      } else {
        // Fix up relative URLs to go to GitHub.
        try {
          // Relative URLs will *fail* this initialisation.
          new URL(linkTarget)
        } catch (error) {
          linkElement.href = `https://github.com${linkTarget}`
        }
      }
    })
  }
}
