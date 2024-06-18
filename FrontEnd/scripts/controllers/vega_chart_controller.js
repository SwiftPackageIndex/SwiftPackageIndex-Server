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
import * as vegaTooltip from 'vega-tooltip'

export class VegaChartController extends Controller {
    static targets = ['plotData', 'eventData']
    static values = { class: String }

    connect() {
        // Store references the two chart classes so they can be looked up as if they were in a dictionary.
        window.CompatiblePackagesChart = CompatiblePackagesChart
        window.TotalErrorsChart = TotalErrorsChart

        // Render the "Show totals" checkbox, if applicable.
        if (this.element.dataset.includeTotals === 'true') {
            this.element.appendChild(this.totalsForm())
        }

        // Render the chart container.
        const chartContainerElement = document.createElement('div')
        chartContainerElement.classList.add('chart-container')
        this.element.appendChild(chartContainerElement)

        // Render the UI for the data set inclusion checkboxes.
        const data = JSON.parse(this.plotDataTarget.textContent)
        this.element.appendChild(this.plotsForm(data))

        // Render the initial chart.
        this.renderChart()
    }

    totalsForm() {
        const formElement = document.createElement('form')
        formElement.classList.add('totals')

        const labelElement = document.createElement('label')
        formElement.appendChild(labelElement)

        const checkboxElement = document.createElement('input')
        checkboxElement.type = 'checkbox'
        checkboxElement.name = 'totals'
        checkboxElement.checked = true
        checkboxElement.addEventListener('change', () => {
            this.renderChart()
        })
        labelElement.appendChild(checkboxElement)

        const labelTextElement = document.createTextNode('Show totals')
        labelElement.appendChild(labelTextElement)

        return formElement
    }

    plotsForm(data) {
        const formElement = document.createElement('form')
        formElement.classList.add('plots')
        data.forEach((dataSet) => {
            const labelElement = document.createElement('label')
            formElement.appendChild(labelElement)

            const checkboxElement = document.createElement('input')
            checkboxElement.type = 'checkbox'
            checkboxElement.name = dataSet.id
            checkboxElement.checked = true
            checkboxElement.addEventListener('change', () => {
                this.renderChart()
                this.updateCheckboxUI()
            })
            labelElement.appendChild(checkboxElement)

            const lineElement = document.createElement('div')
            lineElement.classList.add('line')
            lineElement.style.backgroundColor = ReadyForSwift6Chart.colorForDataSet(dataSet.id)
            labelElement.appendChild(lineElement)

            const labelTextElement = document.createTextNode(dataSet.name)
            labelElement.appendChild(labelTextElement)
            labelElement.replaceChild
        })
        return formElement
    }

    updateCheckboxUI() {
        const checkboxElements = this.element.querySelectorAll('form.plots input[type="checkbox"]')
        const checkedCheckboxElements = this.element.querySelectorAll('form.plots input[type="checkbox"]:checked')

        if (checkedCheckboxElements.length === 1) {
            // Only disable the remaining checked checkbox to allow the others to still be responsive.
            checkedCheckboxElements.forEach((checkbox) => {
                checkbox.disabled = true
            })
        } else {
            // Always enable everything.
            checkboxElements.forEach((checkbox) => {
                checkbox.disabled = false
            })
        }
    }

    renderChart() {
        const eventData = JSON.parse(this.eventDataTarget.textContent)
        const checkboxElements = this.element.querySelectorAll('form.plots input[type="checkbox"]:checked')
        const includedDataSets = Array.from(checkboxElements).map((checkbox) => checkbox.name)
        const plotData = JSON.parse(this.plotDataTarget.textContent).filter((dataSet) =>
            includedDataSets.includes(dataSet.id)
        )

        const includeTotals = this.element.querySelector('form.totals input[type="checkbox"]:checked') ?? false

        const tooltip = new vegaTooltip.Handler({
            offsetX: 15,
            offsetY: 5,
        })

        const chartClass = window[this.classValue]
        const spec = chartClass.spec(includeTotals, plotData, eventData)
        new vega.View(vega.parse(spec), {
            renderer: 'canvas',
            container: this.element.querySelector('.chart-container'),
            hover: true,
            tooltip: tooltip.call,
        }).run()
    }
}

class ReadyForSwift6Chart {
    static spec(includeTotals, plotData, eventData) {
        return {
            $schema: 'https://vega.github.io/schema/vega/v5.json',
            width: 700,
            height: 400,
            config: this.config(),
            data: this.plotData(plotData).concat(this.eventData(eventData)),
            signals: this.signals(plotData),
            scales: this.scales(plotData, includeTotals),
            axes: this.axes(),
            marks: plotData
                .flatMap((dataSet) => this.plotMarks(dataSet))
                .concat(this.totalsMarks(includeTotals, plotData))
                .concat(this.eventMarks(eventData)),
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

    static plotData(data) {
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

    static eventData(data) {
        return {
            name: 'events',
            transform: [
                {
                    type: 'formula',
                    expr: 'datetime(datum.date)',
                    as: 'date',
                },
            ],
            values: data,
        }
    }

    static signals(data) {
        return [
            {
                name: 'minXScale',
                update: "domain('xscale')[0]",
            },
            {
                name: 'maxXScale',
                update: "domain('xscale')[1]",
            },
            {
                name: 'minYScale',
                update: "domain('yscale')[0]",
            },
            {
                name: 'maxYScale',
                update: "domain('yscale')[1]",
            },
        ]
    }

    static scales(data, includeTotals) {
        var maxYScale = data
            .flatMap((dataSet) => dataSet.values.map((element) => element.value))
            .reduce((max, value) => Math.max(max, value), 0)

        if (includeTotals) {
            maxYScale = Math.max(
                maxYScale,
                data.reduce((max, dataSet) => Math.max(max, dataSet?.total ?? 0), 0)
            )
        }

        return [
            {
                name: 'xscale',
                type: 'time',
                domain: [{ signal: 'datetime("2024-05-01")' }, { signal: 'datetime("2024-12-31")' }],
                range: 'width',
            },
            {
                name: 'yscale',
                type: 'linear',
                domain: [0, maxYScale],
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
                title: this.yAxisTitle(),
            },
        ]
    }

    static yAxisTitle() {
        return ''
    }

    static symbolTooltipLabelType() {
        return ''
    }

    static plotMarks(dataSet) {
        return [
            {
                type: 'line',
                from: { data: dataSet.id },
                encode: {
                    enter: {
                        x: { scale: 'xscale', field: 'date' },
                        y: { scale: 'yscale', field: 'value' },
                        stroke: { value: this.colorForDataSet(dataSet.id) },
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
                        fill: { value: this.colorForDataSet(dataSet.id) },
                        tooltip: {
                            signal: `{ 'Value' : datum.value + ' ${this.symbolTooltipLabelType()}', 'Date' : timeFormat(datum.date, '%b %d, %Y'), 'Toolchain' : datum.toolchainId,  '' : datum.toolchainLabel}`,
                        },
                        // {
                        //     signal: "'Result recorded on ' + timeFormat(datum.date, '%b %d, %Y')",
                        // }
                    },
                },
            },
        ]
    }

    static eventMarks(data) {
        return [
            {
                type: 'rect',
                from: { data: 'events' },
                encode: {
                    enter: {
                        xc: { scale: 'xscale', field: 'date' },
                        width: { value: 1 },
                        y: { scale: 'yscale', signal: 'minYScale' },
                        y2: { scale: 'yscale', signal: 'maxYScale' },
                        fill: { value: '#000000' },
                        opacity: { value: 0.3 },
                        tooltip: {
                            signal: 'datum.value',
                        },
                    },
                },
            },
        ]
    }

    static totalsMarks(includeTotals, data) {
        if (includeTotals === false) {
            return []
        }

        return data.map((dataSet) => {
            return {
                type: 'rect',
                from: { data: dataSet.id },
                encode: {
                    enter: {
                        x: { scale: 'xscale', signal: 'minXScale' },
                        x2: { scale: 'xscale', signal: 'maxXScale' },
                        yc: { scale: 'yscale', value: dataSet.total },
                        height: { value: 1 },
                        fill: { value: this.colorForDataSet(dataSet.id) },
                        opacity: { value: 0.3 },
                        tooltip: {
                            value: `${dataSet.name} total: ${dataSet.total}`,
                        },
                    },
                },
            }
        })
    }

    static colorForDataSet(dataSetId) {
        switch (dataSetId) {
            case 'all':
                return '#6495ED'
            case 'apple':
                return '#CD5C5C'
            case 'sswg':
                return '#3CB371'
            default:
                return '#000000'
        }
    }
}

class CompatiblePackagesChart extends ReadyForSwift6Chart {
    static yAxisTitle() {
        return 'Number of packages with zero data race errors'
    }

    static symbolTooltipLabelType() {
        return 'packages'
    }
}

class TotalErrorsChart extends ReadyForSwift6Chart {
    static yAxisTitle() {
        return 'Total data race errors across all packages'
    }

    static symbolTooltipLabelType() {
        return 'errors'
    }
}
