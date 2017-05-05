var webpack = require('webpack');
var path = require('path');

module.exports = {
    entry: 'calendar_heatmap',
    resolve: {
        root: [
            path.join(__dirname, 'src'),
        ]
    },
    output: {
        filename: 'visualization.js',
        libraryTarget: 'amd'
    },
    module: {
        loaders: [
            { test: /tooltip/, loader: 'imports?jQuery=jquery' }
        ]
    },
    externals: [
        'api/SplunkVisualizationBase',
        'api/SplunkVisualizationUtils'
    ]
};