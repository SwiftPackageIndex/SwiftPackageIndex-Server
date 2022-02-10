// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import '@hotwired/turbo'

import './dom_helpers.js'

import { ExternalLinkRetargeter } from './external_link_retargeter.js'
import { SPIWindowMonitor } from './window_monitor.js'
import { SPIPackageListNavigation } from './package_list_navigation.js'
import { SPICopyPackageURLButton } from './copy_buttons.js'
import { SPICopyPackageDependencyButton } from './copy_buttons.js'
import { SPICopyableInput } from './copy_buttons.js'
import { SPIBuildLogNavigation } from './build_log_navigation.js'
import { SPIAutofocus } from './autofocus.js'
import { SPIPlaygroundsAppLinkFallback } from './playgrounds_app_link.js'
import { SPIReadmeElement } from './readme_element.js'
import { SPITabBarElement } from './tab_bar_element.js'
import { SPIShowMoreKeywords } from './show_more_keywords.js'
import { SPISearchFilterSuggestions } from './search_filter_suggestions.js'
import { SPIPanel } from './panel.js'

new ExternalLinkRetargeter()
new SPIWindowMonitor()
new SPIPackageListNavigation()
new SPIBuildLogNavigation()
new SPICopyPackageURLButton()
new SPICopyPackageDependencyButton()
new SPICopyableInput()
new SPIAutofocus()
new SPIPlaygroundsAppLinkFallback()
new SPIShowMoreKeywords()
new SPISearchFilterSuggestions()
new SPIPanel()

customElements.define('spi-readme', SPIReadmeElement)
customElements.define('tab-bar', SPITabBarElement)

import 'normalize.css'
import '../Styles/main.scss'

//# sourceMappingURL=main.js.map
