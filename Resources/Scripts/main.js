import '../Styles/main.scss'

import './dom_helpers.js'
import './highlighting.js'

import { ExternalLinkRetargeter } from './external_link_retargeter.js'
import { SPIPackageListNavigation } from './package_list_navigation.js'
import { SPICopyPackageURLButton } from './copy_buttons.js'
import { SPICopyBadgeMarkdownButtons } from './copy_buttons.js'
import { SPIBuildLogNavigation } from './build_log_navigation.js'
import { SPIReadmeProcessor } from './readme_processor.js'

window.externalLinkRetargeter = new ExternalLinkRetargeter()
window.spiPackageListNavigation = new SPIPackageListNavigation()
window.spiCopyPackageURLButton = new SPICopyPackageURLButton()
window.spiCopyBadgeMarkdownButtons = new SPICopyBadgeMarkdownButtons()
window.buildLogNavigation = new SPIBuildLogNavigation()
window.spiReadmeProcessor = new SPIReadmeProcessor()
