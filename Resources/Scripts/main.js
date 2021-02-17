import '../Styles/main.scss'

import './find_parent_matching.js'
import './highlighting.js'

import { ExternalLinkRetargeter } from './external_link_retargeter.js'
import { SPISearchCore } from './search_core.js'
import { SPISearchFocusHandler } from './search_focus_handler.js'
import { SPISearchKeyboardNavigation } from './search_keyboard_navigation.js'
import { SPICopyPackageURLButton } from './copy_buttons.js'
import { SPICopyBadgeMarkdownButtons } from './copy_buttons.js'
import { SPIBuildLogNavigation } from './build_log_navigation.js'
import { SPIReadmeProcessor } from './readme_processor.js'

window.externalLinkRetargeter = new ExternalLinkRetargeter()
window.spiSearchCore = new SPISearchCore()
window.spiSearchFocusHandler = new SPISearchFocusHandler()
window.spiSearchKeyboardNavigation = new SPISearchKeyboardNavigation()
window.spiCopyPackageURLButton = new SPICopyPackageURLButton()
window.spiCopyBadgeMarkdownButtons = new SPICopyBadgeMarkdownButtons()
window.buildLogNavigation = new SPIBuildLogNavigation()
window.spiReadmeProcessor = new SPIReadmeProcessor()
