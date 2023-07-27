// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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

import { Application } from '@hotwired/stimulus'
import { OverflowingListController } from './overflowing_list_controller.js'
import { ModalPanelController } from './modal_panel_controller.js'
import { ReadmeController } from './readme_controller.js'
import { TabBarController } from './tab_bar_controller.js'
import { PanelButtonController } from './panel_button_controller.js'
import { UseThisPackagePanelController } from './use_this_package_panel_controller.js'

const application = Application.start()
application.register('overflowing-list', OverflowingListController)
application.register('modal-panel', ModalPanelController)
application.register('readme', ReadmeController)
application.register('tab-bar', TabBarController)
application.register('panel-button', PanelButtonController)
application.register('use-this-package-panel', UseThisPackagePanelController)
