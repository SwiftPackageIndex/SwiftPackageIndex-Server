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

import { Controller } from '@hotwired/stimulus'

export class UseThisPackagePanelController extends Controller {
    static targets = ['select', 'snippet']

    connect() {
        this.updateProductSnippet()
    }

    updateProductSnippet() {
        const selectElement = this.selectTarget
        const optionElement = selectElement.options[selectElement.selectedIndex]
        const packageName = optionElement.dataset.package
        const productName = optionElement.dataset.product
        const type = optionElement.dataset.type
        const prefix = type == "plugin" ? ".plugin" : ".product"
        this.snippetTarget.value = `${prefix}(name: "${productName}", package: "${packageName}")`
    }
}
