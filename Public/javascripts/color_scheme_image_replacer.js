export class ColorSchemeImageReplacer {
  constructor() {
    document.addEventListener('DOMContentLoaded', () => {
      // Do an initial pass at replacement when the page loads.
      this.matchImagesToColorScheme()

      // Also watch for colour scheme changes at the system level.
      window.matchMedia('(prefers-color-scheme: dark)').addListener(() => {
        this.matchImagesToColorScheme()
      })
    })
  }

  matchImagesToColorScheme() {
    // For all images in the whole page.
    const imageElements = document.querySelectorAll('img')
    Array.from(imageElements).forEach((imageElement) => {
      // Break down the URL into a path, then grab the filename and extension.
      const imageSourceUrl = new URL(imageElement.src)
      const pathElements = imageSourceUrl.pathname.split('/')
      const filenameParts = pathElements.pop().split('.')
      const filename = filenameParts.shift()
      const extension = filenameParts.shift()

      // Is this an image filename flagged with a light or dark mode suffix?
      if (filename.endsWith('~light') || filename.endsWith('~dark')) {
        const filenameWithoutSuffix = filename.split('~').shift()
        const colorScheme = this.currentColorScheme()
        const newFilename = filenameWithoutSuffix + '~' + colorScheme + '.' + extension
        imageSourceUrl.pathname = pathElements.join('/') + '/' + newFilename
        imageElement.src = imageSourceUrl.toString()
      }
    })
  }

  currentColorScheme() {
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
  }
}
