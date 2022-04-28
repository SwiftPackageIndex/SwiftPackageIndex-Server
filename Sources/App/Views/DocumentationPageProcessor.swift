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

import Vapor
import SwiftSoup

struct DocumentationPageProcessor {
    let document: Document

    init?(rawHtml: String) {
        do {
            document = try SwiftSoup.parse(rawHtml)
            try document.head()?.append(self.stylesheetLink)
            try document.body()?.prepend(self.spiHeader)
            if let analyticsScript = self.analyticsScript {
                try document.head()?.append(analyticsScript)
            }
        } catch {
            return nil
        }
    }

    var stylesheetLink: String {
        """
        <link rel="stylesheet" href="/docc.css?\(ResourceReloadIdentifier.value)">
        """
    }

    var analyticsScript: String? {
        guard Environment.current == .production else { return nil }
        return PublicPage.analyticsScriptTags
    }

    var spiHeader: String {
        """
        <header class="spi">
            <div class="inner">
                <a href="/">
                    <h1><img alt="Logo" src="/images/logo.svg">Swift Package Index</h1>
                </a>
                <form action="/search">
                    <input id="query" name="query" type="search" placeholder="Search Packages" spellcheck="false" autocomplete="off" data-gramm="false">
                    <button type="submit"></button>
                </form>
            </div>
        </header>
        """
    }

    var processedPage: String {
        do {
            return try document.html()
        } catch {
            return "An error occurred while rendering processed documentation."
        }
    }
}
