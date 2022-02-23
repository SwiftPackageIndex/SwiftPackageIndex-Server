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

import { Application } from '@hotwired/stimulus'
import { OverflowingListController } from './overflowing_list_controller.js'
import { ExternalLinkRetargeterController } from './external_link_retargeter_controller.js'

const application = Application.start()
application.register('overflowing-list', OverflowingListController)
application.register('external-link-retargeter', ExternalLinkRetargeterController)
