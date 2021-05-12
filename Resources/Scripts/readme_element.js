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

    // Find all relative links and point them to the formatted version on GitHub.
    const links = this.querySelectorAll('a')
    links.forEach((linkElement) => {
      const linkTarget = linkElement.getAttribute('href')
      try {
        // Relative URLs will *fail* this initialisation.
        new URL(linkTarget)
      } catch (error) {
        console.log(`linkTarget=${linkTarget}`)
        linkElement.href = `https://github.com${linkTarget}`
      }
    })
  }
}
