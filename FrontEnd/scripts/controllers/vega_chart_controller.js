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
import * as vega from 'vega'

export class VegaChartController extends Controller {
    static targets = ['data']

    data = []

    connect() {
        // Grab the data from the embedded `application/json` data element.
        this.data = JSON.parse(this.dataTarget.textContent)

        // Render the UI for the data set inclusion checkboxes.
        this.element.appendChild(this.seriesCheckboxForm())

        // Render the chart container.
        const chartContainerElement = document.createElement('div')
        chartContainerElement.classList.add('chart-container')
        this.element.appendChild(chartContainerElement)

        // Render the initial chart.
        this.renderChart()
    }

    seriesCheckboxForm() {
        const formElement = document.createElement('form')
        this.data.forEach((dataSet) => {
            const labelElement = document.createElement('label')
            formElement.appendChild(labelElement)

            const checkboxElement = document.createElement('input')
            checkboxElement.type = 'checkbox'
            checkboxElement.name = dataSet.id
            checkboxElement.checked = true
            labelElement.appendChild(checkboxElement)

            checkboxElement.addEventListener('change', () => {
                this.renderChart()
            })

            const labelTextElement = document.createTextNode(dataSet.name)
            labelElement.appendChild(labelTextElement)
        })
        return formElement
    }

    renderChart() {
        const checkboxElements = Array.from(this.element.querySelectorAll('input[type="checkbox"]'))
        const includedDataSets = checkboxElements.map((checkbox) => checkbox.name)

        // Only filter when data sets have been specified.
        // The chart won't render correctly if no data sets are included.
        if (includedDataSets.length > 0) {
            this.data = this.data.filter((dataSet) => includedDataSets.includes(dataSet.id))
        }

        const chartElement = new vega.View(vega.parse(ReadyForSwift6Chart.spec(this.data)), {
            renderer: 'canvas',
            container: this.element.querySelector('.chart-container'),
            hover: true,
        }).run()
    }
}

class ReadyForSwift6Chart {
    static spec(data) {
        return {
            $schema: 'https://vega.github.io/schema/vega/v5.json',
            width: 700,
            height: 400,
            padding: 10,
            config: this.config(),
            data: this.data(data),
            scales: this.scales(data),
            axes: this.axes(),
            marks: data.flatMap((dataSet) => this.marks(dataSet)),
        }
    }

    static config() {
        return {
            axis: {
                grid: false,
                labelFont:
                    "system-ui, BlinkMacSystemFont, 'SF Hello', 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif",
                labelFontSize: 14,
                labelFontWeight: 'normal',
                titleFont:
                    "system-ui, BlinkMacSystemFont, 'SF Hello', 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif",
                titleFontSize: 14,
                titleFontWeight: 'normal',
                titlePadding: 20,
            },
        }
    }

    static data(data) {
        return data.map((dataSet) => {
            return {
                name: dataSet.id,
                transform: [
                    {
                        type: 'formula',
                        expr: 'datetime(datum.date)',
                        as: 'date',
                    },
                ],
                values: dataSet.values,
            }
        })
    }

    static scales(data) {
        const maxErrors = data
            .flatMap((dataSet) => dataSet.values.map((element) => element['value']))
            .reduce((max, value) => Math.max(max, value), 0)

        return [
            {
                name: 'xscale',
                type: 'time',
                domain: [{ signal: 'datetime("2024-03-12")' }, { signal: 'datetime("2024-12-31")' }],
                range: 'width',
            },
            {
                name: 'yscale',
                type: 'linear',
                domain: [0, maxErrors],
                range: 'height',
                nice: true,
            },
        ]
    }

    static axes() {
        return [
            {
                orient: 'bottom',
                scale: 'xscale',
                grid: true,
                labelAngle: { value: -45 },
                labelAlign: { value: 'right' },
            },
            {
                orient: 'left',
                scale: 'yscale',
                title: 'Number of compatible packages',
            },
        ]
    }

    static marks(dataSet) {
        return [
            {
                type: 'line',
                from: { data: dataSet.id },
                encode: {
                    enter: {
                        x: { scale: 'xscale', field: 'date' },
                        y: { scale: 'yscale', field: 'value' },
                        stroke: { value: '#356fce' },
                        strokeWidth: { value: 3 },
                    },
                },
            },
            {
                type: 'symbol',
                from: { data: dataSet.id },
                encode: {
                    enter: {
                        x: { scale: 'xscale', field: 'date' },
                        y: { scale: 'yscale', field: 'value' },
                        size: { value: 60 },
                        tooltip: {
                            signal: "timeFormat(datum.snapshotDate, '%b %d, %Y') + ' - ' + datum.numPackages + ' packages'",
                        },
                    },
                },
            },
        ]
    }
}
