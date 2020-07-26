import './find_parent_matching.js'

import { ExternalLinkRetargeter } from './external_link_retargeter.js'
import { SPISearchCore } from './search_core.js'
import { SPISearchFocusHandler } from './search_focus_handler.js'
import { SPISearchKeyboardNavigation } from './search_keyboard_navigation.js'
import { SPICopyPackageURL } from './copy_package_url.js'
import { SPIBuildLogNavigation } from './build_log_navigation.js'

window.externalLinkRetargeter = new ExternalLinkRetargeter()
window.spiSearchCore = new SPISearchCore()
window.spiSearchFocusHandler = new SPISearchFocusHandler()
window.spiSearchKeyboardNavigation = new SPISearchKeyboardNavigation()
window.spiCopyPackageURL = new SPICopyPackageURL()
window.buildLogNavigation = new SPIBuildLogNavigation()
