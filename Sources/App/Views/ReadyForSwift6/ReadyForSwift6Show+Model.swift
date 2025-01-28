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

import Dependencies
import Plot


enum ReadyForSwift6Show {

    struct Model {

        enum ChartKind {
            case compatiblePackages
            case totalErrors
        }

        func readyForSwift6Chart(kind: ChartKind, includeTotals: Bool = false) -> Node<HTML.BodyContext> {
            @Dependency(\.fileManager) var fileManager
            let plotDataPath = fileManager.workingDirectory()
                .appending("Resources/ChartData/\(kind.dataFile)")
            let eventDataPath = fileManager.workingDirectory()
                .appending("Resources/ChartData/rfs6-events.json")
            guard let plotData = fileManager.contents(atPath: plotDataPath)?.compactJson(),
                  let eventData = fileManager.contents(atPath: eventDataPath)?.compactJson()
            else { return .p("Couldn’t load chart data.") }

            return .div(
                .data(named: "controller", value: "vega-chart"),
                .data(named: "vega-chart-class-value", value: kind.jsClassName),
                .data(named: "include-totals", value: String(includeTotals)),
                .script(
                    .data(named: "vega-chart-target", value: "plotData"),
                    .attribute(named: "type", value: "application/json"),
                    .raw(plotData)
                ),
                .script(
                    .data(named: "vega-chart-target", value: "eventData"),
                    .attribute(named: "type", value: "application/json"),
                    .raw(eventData)
                )
            )
        }
    }
}

private extension ReadyForSwift6Show.Model.ChartKind {
    var dataFile: String {
        get {
            switch self {
                case .compatiblePackages: return "rfs6-packages.json"
                case .totalErrors: return "rfs6-errors.json"
            }
        }
    }

    var jsClassName: String {
        get {
            switch self {
                case .compatiblePackages: return "CompatiblePackagesChart"
                case .totalErrors: return "TotalErrorsChart"
            }
        }
    }
}

private extension Data {
    func compactJson() -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: self),
              let compactedJsonData = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]),
              let compactJson = String(data: compactedJsonData, encoding: .utf8)
        else { return nil }
        return compactJson
    }
}
