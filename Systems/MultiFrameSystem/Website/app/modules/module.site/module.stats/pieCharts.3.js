
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site.stats')
        .directive('pieCharts', pieChartsFactory);
    /*********************************************************************************************************************************************************************/
    function pieChartsFactory() {


        return {
            restrict: 'EA',
            scope: {
                obj: '='
            },

            link: function (scope, element, attrs, ngModel) {

               
                //scope.obj.changeOptionsCallback = function (options) {
                //    scope.options = options;
                //    drawChart();
                //};

                scope.obj.changeDataCallback = function (data) {
                    scope.data = data;                    
                    
                    drawChart();
                };


                drawChart();

                google.load("visualization", "1", { packages: ["corechart"], "callback": createChart });
                var chart;
               // var options;
                function createChart() {
                    chart = new google.visualization.PieChart(element[0]);
                    drawChart();
                }
                function drawChart() {

                    if (!scope.obj.data || !chart)
                        return;

                    if (scope.obj.data.type == 'Duration') {
                        var data = google.visualization.arrayToDataTable([
                                             ['Task', 'Hours per Day'],
                                             ['Used', scope.obj.data.usedDuration],
                                             ['Saving', scope.obj.data.savingDuration]

                        ]);
                    } else {
                        var data = google.visualization.arrayToDataTable([
                                            ['Task', 'Hours per Day'],
                                            ['Used', scope.obj.data.usedQuantity],
                                            ['Saving', scope.obj.data.savingQuantity]

                        ]);
                    }
                   

                    var options = {
                        title: '',
                        backgroundColor: 'transparent',
                        colors: ['#4086AA', '#91C3DC'],
                        is3D: true,
                    };

                   
                    chart.draw(data, options);

                    //scope.$on('pieDetails', function (event, data1) {
                    //    scope.obj = data1;
                    //    chart.draw(data, options);

                    //});
                }

               






            }
        };
       

        
    }
    /*******************************************************************************************************************************************************************************/

})(angular);






