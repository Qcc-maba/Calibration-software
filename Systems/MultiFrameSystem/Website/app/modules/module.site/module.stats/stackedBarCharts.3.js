
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site.stats')
        .directive('stackedBarCharts', stackedBarChartsFactory);
    /*********************************************************************************************************************************************************************/
    function stackedBarChartsFactory() {


        return {
            restrict: 'EA',
            scope: {
                obj1: '='
            },

            link: function (scope, element, attrs, ngModel) {

               
                scope.obj1.changeOptionsCallback = function (options) {
                    scope.options = options;
                    drawChart();
                };

                scope.obj1.changeDataCallback = function (data) {
                    scope.data = data;

                    drawChart();
                };


                drawChart();

                google.load("visualization", "1", { packages: ["corechart", 'bar'], "callback": createChart });
                var chart;
                // var options;
                function createChart() {
                    chart = new google.visualization.BarChart(element[0]);
                    drawChart();
                }
                function drawChart() {

                    if (!scope.obj1.data || !chart)
                        return;

                 
                    var data = google.visualization.arrayToDataTable(scope.obj1.data);

                    var options = {
                        width: 600,
                        height: 400,
                        backgroundColor: 'transparent',
                        colors: ['#4086AA', '#91C3DC'],
                        legend: { position: 'top', maxLines: 3 },
                        bar: { groupWidth: '75%' },
                        isStacked: true
                    };

                    chart.draw(data, options);

                  
                }








            }
        };



    }
    /*******************************************************************************************************************************************************************************/

})(angular);






