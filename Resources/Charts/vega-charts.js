var spec = JSON.parse(document.getElementById('vega-spec-###').textContent)
const vegaChart = new vega.View(vega.parse(spec), { renderer: 'canvas' }).initialize('#vega-chart-###').run()

var checkbox = document.getElementById('toggle-line')

checkbox.addEventListener('change', function () {
    if (this.checked) {
        view.data('apple-packages', {
            name: 'apple-packages',
            transform: [
                {
                    type: 'formula',
                    expr: 'datetime(datum.snapshot)',
                    as: 'snapshotDate',
                },
            ],
            values: [
                { snapshot: '2024-03-05', numPackages: 30 },
                { snapshot: '2024-03-18', numPackages: 42 },
                { snapshot: '2024-03-26', numPackages: 43 },
                { snapshot: '2024-04-15', numPackages: 65 },
                { snapshot: '2024-05-09', numPackages: 89 },
                { snapshot: '2024-06-30', numPackages: 89 },
                { snapshot: '2024-07-29', numPackages: 122 },
            ],
        }).run()
    } else {
        view.data('apple-packages', []).run()
    }
})
