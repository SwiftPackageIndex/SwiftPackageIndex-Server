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

@testable import App

import Testing


extension AllTests.DocRouteTests {

    @Test(arguments: [DocRoute.Fragment.documentation, .tutorials])
    func cacheControl_html(fragment: DocRoute.Fragment) throws {
        for docVersion in [DocVersion.reference("1.2.3"), .reference("main"), .current(referencing: "1.2.3")] {
            let route = DocRoute(owner: "owner", repository: "repo", docVersion: docVersion, fragment: fragment)
            #expect(route.cacheControl == "public, max-age=0, s-maxage=600")
        }
    }

    @Test(arguments: [DocRoute.Fragment.css, .data, .faviconIco, .faviconSvg, .images, .img, .index, .js, .linkablePaths, .themeSettings, .svgImages, .svgImg, .videos])
    func cacheControl_asset_tag(fragment: DocRoute.Fragment) throws {
        let route = DocRoute(owner: "owner", repository: "repo", docVersion: .reference("1.2.3"), fragment: fragment)
        #expect(route.cacheControl == "public, max-age=86400, s-maxage=86400, no-transform")
    }

    @Test(arguments: [DocVersion.reference("main"), .current(), .current(referencing: "1.2.3")])
    func cacheControl_asset_mutableReference(docVersion: DocVersion) throws {
        let route = DocRoute(owner: "owner", repository: "repo", docVersion: docVersion, fragment: .css)
        #expect(route.cacheControl == "public, max-age=300, s-maxage=300, no-transform")
    }

}
