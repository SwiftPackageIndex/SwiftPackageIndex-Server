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

import Foundation
import Plot

enum ReadyForSwift6Show {
    struct Model {
        func readyForSwift6Chart(identifier: String) -> Node<HTML.BodyContext> {
            let chartDataPath = Current.fileManager.workingDirectory().appending("Resources/ChartData/\(identifier).json")
            guard let chartData = Current.fileManager.contents(atPath: chartDataPath)?.compactJson()
            else { return .p("Couldn’t load chart data.") }

            return .div(
                .class("vega-chart"),
                .data(named: "controller", value: "vega-chart"),
                .script(
                    .data(named: "vega-chart-target", value: "data"),
                    .attribute(named: "type", value: "application/json"),
                    .raw(chartData)
                )
            )
        }
    }
}

private extension Data {
    func compactJson() -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: self),
              let compactedJsonData = try? JSONSerialization.data(withJSONObject: json),
              let compactJson = String(data: compactedJsonData, encoding: .utf8)
        else { return nil }
        return compactJson
    }
}
