import { OpenExternalLinksInBlankTarget } from './links.js'
import { SPISearchCore } from './search_core.js'
import { SPISearchKeyboardNavigation } from './search_keyboard_navigation.js'

window.externalLinkRetargeter = new OpenExternalLinksInBlankTarget()
window.spiSearchCore = new SPISearchCore()
window.spiSearchKeyboardNavigation = new SPISearchKeyboardNavigation()
