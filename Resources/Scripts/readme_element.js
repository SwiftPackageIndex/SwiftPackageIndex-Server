export class SPIReadmeElement extends HTMLDivElement {
  constructor() {
    super()
    console.log('spi-readme constructor')
  }
}

// export class SPIReadmeProcessor {
//   constructor() {
//     document.addEventListener('turbo:load', () => {
//       const readmeNode = document.querySelector('article.readme')
//       if (!readmeNode) return
//
//       const readmeBaseUrl = new URL(readmeNode.getAttribute('data-readme-base-url'))
//
//       console.log('Hello, world.')
//
//       // Find all relative image URLs and point them at the raw image sources.
//       const readmeImages = readmeNode.querySelectorAll('img')
//       readmeImages.forEach((imageElement) => {
//         const imageSource = imageElement.getAttribute('src')
//         try {
//           // Relative URLs will *fail* this initialisation.
//           new URL(imageSource)
//         } catch (error) {
//           imageElement.src = `${readmeBaseUrl}${imageSource}`
//         }
//       })
//
//       // Find all relative links and point them to the formatted version on GitHub.
//       // Note: This is very brittle code that relies on everything being hosted with GitHub.
//       const links = readmeNode.querySelectorAll('a')
//       links.forEach((linkElement) => {
//         const linkTarget = linkElement.getAttribute('href')
//         try {
//           // Relative URLs will *fail* this initialisation.
//           new URL(linkTarget)
//         } catch (error) {
//           // First, make a new base URL with 'blob' inserted just before the branch name.
//           // This relies on the branch name being the last path component.
//           const adjustedBaseUrl = new URL(readmeBaseUrl)
//           const basePathComponents = adjustedBaseUrl.pathname.split('/')
//           basePathComponents.splice(basePathComponents.length - 2, 0, 'blob')
//           adjustedBaseUrl.pathname = basePathComponents.join('/')
//
//           // Construct a new URL based on the modified base path and the relative URL.
//           // All relative URLs will be resolved during creation of the URL instance.
//           const newUrl = new URL(`${adjustedBaseUrl}${linkTarget}`)
//
//           // Adjust the host of the newly created URL to be GitHub main, not the raw subdomain.
//           newUrl.host = 'github.com'
//
//           // Substitute this Frankenstein's monster of a URL.
//           linkElement.href = newUrl
//         }
//       })
//
//       // Find all tasklist items and adjust the incorrect markup output from our Markdown parser.
//       const listParagraphElements = readmeNode.querySelectorAll('li>p')
//       listParagraphElements.forEach((paragraphElement) => {
//         const parentElement = paragraphElement.parentNode
//         const firstChildElement = parentElement.firstChild
//         if (
//           firstChildElement &&
//           firstChildElement instanceof HTMLInputElement &&
//           firstChildElement.type == 'checkbox'
//         ) {
//           // We found a paragraph inside a list item where the first child of the list item
//           // is a checkbox. This is the situation in which we want to adjust the markup.
//           // Move the input element inside the paragraph element as the first child.
//           firstChildElement.remove
//           paragraphElement.prepend(firstChildElement)
//         }
//       })
//     })
//   }
// }
