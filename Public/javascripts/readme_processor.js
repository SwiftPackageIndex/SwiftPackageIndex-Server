export class SPIReadmeProcessor {
  constructor() {
    document.addEventListener('DOMContentLoaded', () => {
      const readmeNode = document.querySelector('article.readme')
      if (!readmeNode) { return }

      const readmeBaseUrl = new URL(readmeNode.getAttribute('data-readme-base-url'))
      const readmeImages = readmeNode.querySelectorAll('img')
      readmeImages.forEach((image) => {
        const imageSource = image.getAttribute('src')
        try {
          // Relative URLs will *fail* this initialisation.
          new URL(imageSource)
        } catch(error) {
          image.src = `${readmeBaseUrl}${imageSource}`
        }
      })
    })
  }
}
