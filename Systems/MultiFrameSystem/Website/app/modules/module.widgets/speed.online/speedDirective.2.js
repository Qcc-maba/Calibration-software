(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('speed', speedFactory);
    /*******************************************************************************************************************************************************************/
    function speedFactory($log) {

        return {
            restrict: 'EA',
            require: '?ngModel',
            scope: {
                obj: '='
            },

            link: function (scope, element, attrs, ngModel) {
                var options;
                var data;
                var chart;

                if (!ngModel) return;
                ngModel.$render = function () {
                    if (chart != null) {
                        scope.val = ngModel.$viewValue;
                        data.setValue(0, 1, scope.val);
                        chart.draw(data, options);
                    }
            
                };
                //google.load("visualization", "1", { packages: ["gauge"] });
                google.load("visualization", "1", {packages: ["gauge"], "callback": drawChart });
                //google.setOnLoadCallback(function () {
                 
                //        drawChart()
                
                //});
             
                function drawChart() {
                  
                     data = google.visualization.arrayToDataTable([
                          ['Label', 'Value'],
                          [scope.obj.data.Label, scope.obj.data.Value]
                       
       
                   ]);

                    options = {
                        width: 400, height: scope.obj.options.height,
                        redFrom: scope.obj.options.redFrom, redTo: scope.obj.options.redTo,
                        yellowFrom: scope.obj.options.yellowFrom, yellowTo: scope.obj.options.yellowTo,
                        majorTicks: scope.obj.options.majorTicks,
                        backgroundColor: 'transparent',
                        minorTicks: scope.obj.options.minorTicks,
                        max: scope.obj.options.max,
                        min: scope.obj.options.min
                    };

                    chart = new google.visualization.Gauge(element[0]);

                    chart.draw(data, options);

               
                   
                  
                
                }







    
            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);
