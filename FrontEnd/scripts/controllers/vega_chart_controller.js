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

    connect() {
        const data = JSON.parse(this.dataTarget.textContent)

        console.log(data)
        data.forEach((dataSet) => {
            this.addCheckbox(this.element, dataSet.id, dataSet.name)
        })

        VegaChart.renderChart(this.element, data)
    }

    addCheckbox(containerElement, id, name) {
        const checkboxElement = document.createElement('input')
        checkboxElement.type = 'checkbox'
        checkboxElement.id = `checkbox-${id}`
        checkboxElement.value = id
        checkboxElement.checked = true
        containerElement.appendChild(checkboxElement)

        const labelElement = document.createElement('label')
        labelElement.htmlFor = `checkbox-${id}`
        labelElement.textContent = name
        containerElement.appendChild(labelElement)
    }
}

class VegaChart {
    static renderChart(containerElement, data) {
        const chartElement = new vega.View(vega.parse(this.chartSpec(data)), {
            renderer: 'canvas',
            container: containerElement,
            hover: true,
        }).run()
    }

    chartSpec(data) {
        return {
            $schema: this.specSchema(),
            width: 700,
            height: 400,
            padding: 10,
            config: this.specConfig(),
            data: this.specData(data),
            scales: this.specScales(data),
            axes: this.specAxes(),
            marks: [
                this.specBarBackground(),
                this.specBar(data),
                this.specTextTotalRespondents(data),
                this.specTextLabelOverlay(),
                this.specTextPercentageOverlay(data),
            ],
        }
    }

    specConfig() {
        return {
            axis: {
                grid: false,
                labelFont: '-apple-system',
                labelFontSize: 14,
                labelFontWeight: 'normal',
                titleFont: '-apple-system',
                titleFontSize: 14,
                titleFontWeight: 'normal',
                titlePadding: 20,
            },
        }
    }

    specData(data) {
        return [
            {
                name: 'table',
                values: data.values,
                transform: this.specDataTransform(),
            },
        ]
    }

    // render(scriptElement, data) {
    //     // Insert a wrapper for the header, chart, and control strip.
    //     const wrapperElement = document.createElement('div')
    //     wrapperElement.classList.add('chart')
    //     scriptElement.parentNode.insertBefore(wrapperElement, scriptElement)

    //     // Create the header tag with the question title.
    //     const headerElement = document.createElement('h3')
    //     headerElement.id = `q${data.question}`
    //     wrapperElement.appendChild(headerElement)

    //     // Add the link inside the chart header.
    //     const headerPermalinkElement = document.createElement('a')
    //     if (data.link == 'permalink') {
    //         headerPermalinkElement.href = `#q${data.question}`
    //         headerPermalinkElement.classList.add('permalink')
    //         headerPermalinkElement.title = 'Permalink'
    //     } else {
    //         headerPermalinkElement.href = data.link
    //         headerPermalinkElement.title = `View the raw data for Question ${data.question}`
    //     }
    //     headerElement.appendChild(headerPermalinkElement)

    //     if (data.link == 'permalink') {
    //         // Add the permalink icon inside the link.
    //         const headerPermalinkIconElement = document.createElement('img')
    //         headerPermalinkIconElement.src = '/assets/images/permalink.svg'
    //         headerPermalinkElement.appendChild(headerPermalinkIconElement)
    //     }

    //     // Add the question number "QXXX" inside the link.
    //     headerPermalinkElement.insertAdjacentText('beforeend', `Q${data.question}:`)

    //     // Add the question title inside the header, after the link.
    //     headerElement.insertAdjacentHTML('beforeend', data.title)

    //     // If this is a slice chart, append the slice information inside a span
    //     if (data.chartType == 'slice') {
    //         headerElement.insertAdjacentHTML('beforeend', `&ndash; <span>Filtered by ${data.sliceDescription}.</span>`)
    //     }

    //     // Add a container for both the interactive, and image chart to the wrapper.
    //     const chartElement = document.createElement('div')
    //     chartElement.classList.add('vega')
    //     wrapperElement.appendChild(chartElement)

    //     // Add the container for the Vega canvas or SVG.
    //     const vegaElement = document.createElement('div')
    //     chartElement.appendChild(vegaElement)

    //     // Add the image tag for smaller devices.
    //     const imageElement = document.createElement('img')
    //     imageElement.setAttribute('aria-disabled', 'true')
    //     imageElement.alt = data.title
    //     chartElement.appendChild(imageElement)

    //     // Chart controls only get added for raw data charts.
    //     if (data.chartType == 'raw') {
    //         const chartControlsElement = document.createElement('div')
    //         chartControlsElement.classList.add('controls')
    //         wrapperElement.appendChild(chartControlsElement)

    //         // Add a select drop-down for switching the Y-axis.
    //         const dropDownElement = document.createElement('select')
    //         const xAxisSurveyResponses = document.createElement('option')
    //         xAxisSurveyResponses.text = `Chart based on ${commaFormattedNumber(window.surveyResponses)} survey responses`
    //         xAxisSurveyResponses.value = 'percentageOfSurvey'
    //         if (data.percentageField == 'percentageOfSurvey') {
    //             xAxisSurveyResponses.selected = 'selected'
    //         }
    //         dropDownElement.add(xAxisSurveyResponses)
    //         const xAxisQuestionResponses = document.createElement('option')
    //         xAxisQuestionResponses.text = `Chart based on ${commaFormattedNumber(data.questionResponses)} question responses`
    //         xAxisQuestionResponses.value = 'percentageOfQuestion'
    //         if (data.percentageField == 'percentageOfQuestion') {
    //             xAxisQuestionResponses.selected = 'selected'
    //         }
    //         dropDownElement.add(xAxisQuestionResponses)
    //         chartControlsElement.appendChild(dropDownElement)

    //         // Keep a reference to the chart object inside the select element.
    //         dropDownElement.chartObject = this

    //         // When the drop-down selection changes, re-render the chart.
    //         dropDownElement.addEventListener('change', function (event) {
    //             data.percentageField = event.target.value

    //             // Re-render the charts with the new X-axis maximum.
    //             event.target.chartObject.renderVegaImage(data, 500, vegaElement, imageElement)
    //             event.target.chartObject.renderVegaChart(data, 700, vegaElement)
    //         })

    //         // Add the link to the help document.
    //         const helpLinkElement = document.createElement('a')
    //         helpLinkElement.href = '/2019/a-note-about-this-data/'
    //         helpLinkElement.innerText = '?'
    //         helpLinkElement.title = 'A Note About this Survey Data'
    //         helpLinkElement.target = '_blank'
    //         chartControlsElement.appendChild(helpLinkElement)
    //     }

    //     // Finally, remove the script element.
    //     scriptElement.remove()

    //     // Render the chart as both a mobile image, and an interactive chart for desktops.
    //     this.renderVegaImage(data, 500, vegaElement, imageElement)
    //     this.renderVegaChart(data, 700, vegaElement)
    // }

    // renderVegaImage(data, width, chartElement, imageElement) {
    //     new vega.View(vega.parse(this.chartSpec(data, width)), {
    //         renderer: 'svg',
    //         container: chartElement,
    //     })
    //         .toImageURL('png', window.devicePixelRatio)
    //         .then(function (url) {
    //             imageElement.src = url
    //         })
    // }

    // renderVegaChart(data, width, chartElement) {
    //     const vegaView = new vega.View(vega.parse(this.chartSpec(data, width)), {
    //         renderer: 'svg',
    //         container: chartElement,
    //         hover: true,
    //     })

    //     // Create the tooltip handler from the tooltip plugin.
    //     const tooltip = new vegaTooltip.Handler({
    //         offsetX: 15,
    //         offsetY: 5,
    //     })

    //     // Initialise the tooltip handler and render the chart.
    //     vegaView.tooltip(tooltip.call).runAsync()
    // }

    // specSchema() {
    //     return 'https://vega.github.io/schema/vega/v5.json'
    // }

    // responsesTooltip() {
    //     return { signal: "datum.formattedResponses + ' responses'" }
    // }

    // barColor() {
    //     return '#F5B743'
    // }

    // barBackgroundColor() {
    //     return '#FDF0D9'
    // }
}

// class SurveyPercentageChart extends SurveyChart {
//     constructor(element, data) {
//         super()
//         this.render(element, data)
//     }

//     specDataTransform() {
//         // If a sort parameter has been specified in the query string, sort by ie!
//         const urlParams = new URLSearchParams(window.location.search)
//         const sortParameter = urlParams.get('sort')
//         const orderParameter = urlParams.get('order')
//         if (sortParameter && orderParameter) {
//             return [
//                 {
//                     type: 'collect',
//                     sort: { field: sortParameter, order: orderParameter },
//                 },
//             ]
//         } else if (sortParameter) {
//             return [
//                 {
//                     type: 'collect',
//                     sort: { field: sortParameter },
//                 },
//             ]
//         } else {
//             return []
//         }
//     }

//     specScales(data) {
//         return [
//             {
//                 name: 'percentage_scale',
//                 domain: { data: 'table', field: data.percentageField },
//                 domainMin: 0,
//                 domainMax: 100,
//                 range: 'width',
//             },
//             {
//                 name: 'label_scale',
//                 type: 'band',
//                 domain: { data: 'table', field: 'label' },
//                 range: 'height',
//                 padding: 0.15,
//             },
//         ]
//     }

//     specAxes() {
//         return [
//             {
//                 orient: 'left',
//                 scale: 'label_scale',
//                 labels: false,
//             },
//             {
//                 orient: 'bottom',
//                 scale: 'percentage_scale',
//                 encode: {
//                     labels: {
//                         update: {
//                             text: {
//                                 signal: "datum.value + '%'",
//                             },
//                         },
//                     },
//                 },
//             },
//         ]
//     }

//     specBarBackground() {
//         return {
//             type: 'rect',
//             from: { data: 'table' },
//             encode: {
//                 enter: {
//                     // A full width rectangular mark for the bar background.
//                     x: { scale: 'percentage_scale', value: 0.2 },
//                     y: { scale: 'label_scale', field: 'label' },
//                     width: { scale: 'percentage_scale', value: 100 },
//                     height: { scale: 'label_scale', band: true },
//                     fill: { value: this.barBackgroundColor() },
//                     tooltip: this.responsesTooltip(),
//                 },
//             },
//         }
//     }

//     specBar(data) {
//         return {
//             type: 'rect',
//             from: { data: 'table' },
//             encode: {
//                 enter: {
//                     x: { scale: 'percentage_scale', value: 0.2 },
//                     y: { scale: 'label_scale', field: 'label' },
//                     width: { scale: 'percentage_scale', field: data.percentageField },
//                     height: { scale: 'label_scale', band: 1 },
//                     fill: { value: this.barColor() },
//                     cornerRadiusTopRight: { value: 8 },
//                     cornerRadiusBottomRight: { value: 8 },
//                     tooltip: this.responsesTooltip(),
//                 },
//             },
//         }
//     }

//     specTextTotalRespondents(data) {
//         return {
//             type: 'text',
//             encode: {
//                 enter: {
//                     text: { value: data.topLabelText },
//                     x: { scale: 'percentage_scale', value: 50, band: 0.5 },
//                     dy: { value: -5 },
//                     font: { value: 'Merriweather' },
//                     fontSize: { value: 13 },
//                     baseline: { value: 'bottom' },
//                     align: { value: 'center' },
//                     tooltip: { value: data.topLabelTooltip },
//                 },
//             },
//         }
//     }

//     specTextLabelOverlay() {
//         return {
//             type: 'text',
//             from: { data: 'table' },
//             encode: {
//                 enter: {
//                     text: { field: 'label' },
//                     x: { value: 8 },
//                     y: { scale: 'label_scale', field: 'label', band: 0.5 },
//                     limit: { scale: 'percentage_scale', value: 98 },
//                     font: { value: 'Merriweather' },
//                     fontSize: { value: 14 },
//                     baseline: { value: 'middle' },
//                     align: { value: 'left' },
//                     tooltip: this.responsesTooltip(),
//                 },
//             },
//         }
//     }

//     specTextPercentageOverlay(data) {
//         return {
//             type: 'text',
//             from: { data: 'table' },
//             encode: {
//                 enter: {
//                     text: { signal: `datum.${data.percentageField} + '%'` },
//                     x: { value: -8 },
//                     y: { scale: 'label_scale', field: 'label', band: 0.5 },
//                     font: { value: 'Merriweather' },
//                     fontSize: { value: 14 },
//                     fontWeight: { value: 'bold' },
//                     baseline: { value: 'middle' },
//                     align: { value: 'right' },
//                 },
//             },
//         }
//     }

//     static addChart(data) {
//         SurveyChart.addChart(this, data)
//     }
// }

// class SurveyOpinionChart extends SurveyChart {
//     constructor(element, data) {
//         super()
//         this.render(element, data)
//     }

//     chartSpec(data, width) {
//         return {
//             $schema: this.specSchema(),
//             width: width,
//             height: 350,
//             padding: 10,
//             config: this.specConfig(),
//             data: this.specData(data),
//             scales: this.specScales(data),
//             axes: this.specAxes(),
//             marks: [
//                 this.specBarBackground(),
//                 this.specBar(data),
//                 this.specTextTotalRespondents(data),
//                 this.specTextPercentageOverlay(data),
//                 this.specTextOpinionKeyOverlay(data.leftOpinionLabel, 'left'),
//                 this.specTextOpinionKeyOverlay(data.centerOpinionLabel, 'center'),
//                 this.specTextOpinionKeyOverlay(data.rightOpinionLabel, 'right'),
//                 this.specTextAverageLabelOverlay(data),
//                 this.specTextAverageValueOverlay(data),
//             ],
//         }
//     }

//     specDataTransform() {
//         return []
//     }

//     specScales(data) {
//         return [
//             {
//                 name: 'label_scale',
//                 type: 'band',
//                 domain: { data: 'table', field: 'label' },
//                 range: 'width',
//                 padding: 0.1,
//                 round: true,
//             },
//             {
//                 name: 'percentage_scale',
//                 domain: { data: 'table', field: data.percentageField },
//                 domainMin: 0,
//                 domainMax: 100,
//                 range: 'height',
//             },
//         ]
//     }

//     specAxes() {
//         return [
//             {
//                 orient: 'left',
//                 scale: 'percentage_scale',
//                 encode: {
//                     labels: {
//                         update: {
//                             text: {
//                                 signal: "datum.value + '%'",
//                             },
//                         },
//                     },
//                 },
//             },
//             {
//                 orient: 'bottom',
//                 scale: 'label_scale',
//             },
//         ]
//     }

//     specBarBackground() {
//         return {
//             type: 'rect',
//             from: { data: 'table' },
//             encode: {
//                 enter: {
//                     x: { scale: 'label_scale', field: 'label' },
//                     y: { scale: 'percentage_scale', value: 0 },
//                     width: { scale: 'label_scale', band: 1 },
//                     y2: { scale: 'percentage_scale', value: 100 },
//                     fill: { value: this.barBackgroundColor() },
//                     tooltip: this.responsesTooltip(),
//                 },
//             },
//         }
//     }

//     specBar(data) {
//         return {
//             type: 'rect',
//             from: { data: 'table' },
//             encode: {
//                 enter: {
//                     x: { scale: 'label_scale', field: 'label' },
//                     y: { scale: 'percentage_scale', field: data.percentageField },
//                     width: { scale: 'label_scale', band: 1 },
//                     y2: { scale: 'percentage_scale', value: 0 },
//                     fill: { value: this.barColor() },
//                     cornerRadiusTopLeft: { value: 8 },
//                     cornerRadiusTopRight: { value: 8 },
//                     tooltip: this.responsesTooltip(),
//                 },
//             },
//         }
//     }

//     specTextTotalRespondents(data) {
//         return {
//             type: 'text',
//             encode: {
//                 enter: {
//                     text: { value: data.topLabelText },
//                     x: { scale: 'label_scale', value: 5, band: 0.5 },
//                     dy: { value: -20 },
//                     font: { value: 'Merriweather' },
//                     fontSize: { value: 13 },
//                     baseline: { value: 'bottom' },
//                     align: { value: 'center' },
//                     tooltip: { value: data.topLabelTooltip },
//                 },
//             },
//         }
//     }

//     specTextPercentageOverlay(data) {
//         return {
//             type: 'text',
//             from: { data: 'table' },
//             encode: {
//                 enter: {
//                     text: { signal: `datum.${data.percentageField} + '%'` },
//                     x: { scale: 'label_scale', field: 'label', band: 0.5 },
//                     y: { scale: 'percentage_scale', field: data.percentageField },
//                     dy: { value: -5 },
//                     font: { value: 'Merriweather' },
//                     fontSize: { value: 14 },
//                     fontWeight: { value: 'bold' },
//                     baseline: { value: 'bottom' },
//                     align: { value: 'center' },
//                     tooltip: this.responsesTooltip(),
//                 },
//             },
//         }
//     }

//     specTextOpinionKeyOverlay(label, position) {
//         return {
//             type: 'text',
//             encode: {
//                 enter: {
//                     text: { value: label },
//                     x: this.specTextOpinionKeyOverlayX(position),
//                     y: { scale: 'percentage_scale', value: 0 },
//                     dy: { value: 40 },
//                     font: { value: 'Merriweather' },
//                     fontSize: { value: 14 },
//                     baseline: { value: 'middle' },
//                     align: { value: position },
//                 },
//             },
//         }
//     }

//     specTextAverageLabelOverlay(data) {
//         return {
//             type: 'text',
//             encode: {
//                 enter: {
//                     text: { value: 'Average' },
//                     x: { scale: 'label_scale', value: Math.trunc(data.average), band: 0.5 },
//                     y: { scale: 'percentage_scale', value: 100 },
//                     dy: { value: 20 },
//                     font: { value: 'Merriweather' },
//                     fontSize: { value: 11 },
//                     baseline: { value: 'bottom' },
//                     align: { value: 'center' },
//                 },
//             },
//         }
//     }

//     specTextAverageValueOverlay(data) {
//         return {
//             type: 'text',
//             encode: {
//                 enter: {
//                     text: { value: data.average },
//                     x: { scale: 'label_scale', value: Math.trunc(data.average), band: 0.5 },
//                     y: { scale: 'percentage_scale', value: 100 },
//                     dy: { value: 23 },
//                     font: { value: 'Merriweather' },
//                     fontSize: { value: 14 },
//                     fontWeight: { value: 'bold' },
//                     baseline: { value: 'top' },
//                     align: { value: 'center' },
//                 },
//             },
//         }
//     }

//     specTextOpinionKeyOverlayX(position) {
//         switch (position) {
//             case 'left':
//                 return { scale: 'label_scale', value: 1, band: 0 }
//             case 'center':
//                 return { scale: 'label_scale', value: 5, band: 0.5 }
//             case 'right':
//                 return { scale: 'label_scale', value: 10, band: 1 }
//             default:
//                 return {}
//         }
//     }

//     static addChart(data) {
//         SurveyChart.addChart(this, data)
//     }
// }
