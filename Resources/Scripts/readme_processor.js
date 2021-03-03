export class SPIReadmeProcessor {
  constructor() {
    document.addEventListener('turbolinks:load', () => {
      const readmeNode = document.querySelector('article.readme')
      if (!readmeNode) {
        return
      }

      const readmeBaseUrl = new URL(
        readmeNode.getAttribute('data-readme-base-url')
      )

      // Find all relative image URLs and point them at the raw image sources.
      const readmeImages = readmeNode.querySelectorAll('img')
      readmeImages.forEach((image) => {
        const imageSource = image.getAttribute('src')
        try {
          // Relative URLs will *fail* this initialisation.
          new URL(imageSource)
        } catch (error) {
          image.src = `${readmeBaseUrl}${imageSource}`
        }
      })

      // Find all relative links and point them to the formatted version on GitHub.
      // Note: This is very brittle code, that relies on everything being hosted with GitHub.
      const links = readmeNode.querySelectorAll('a')
      links.forEach((link) => {
        const linkTarget = link.getAttribute('href')
        try {
          // Relative URLs will *fail* this initialisation.
          new URL(linkTarget)
        } catch (error) {
          // First, make a new base URL with 'blob' inserted just before the branch name.
          // This relies on the branch name being the last path component.
          const adjustedBaseUrl = new URL(readmeBaseUrl)
          const basePathComponents = adjustedBaseUrl.pathname.split('/')
          basePathComponents.splice(basePathComponents.length - 2, 0, 'blob')
          adjustedBaseUrl.pathname = basePathComponents.join('/')

          // Construct a new URL based on the modified base path and the relative URL.
          // All relative URLs will be resolved during creation of the URL instance.
          const newUrl = new URL(`${adjustedBaseUrl}${linkTarget}`)

          // Adjust the host of the newly created URL to be GitHub main, not the raw subdomain.
          newUrl.host = 'github.com'

          // Substitute this Frankenstein's monster of a URL.
          link.href = newUrl
        }
      })
    })
  }
}
