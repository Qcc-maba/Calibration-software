
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site.preview')
       .directive('graph', graphFactory);
    /*******************************************************************************************************************************************************************/
    function graphFactory() {


        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.site/module.preview/graph/graph.html',
            link: function (scope, element, attrs, ngModel) {


                

                google.charts.load('current', { 'packages': ['corechart'] });
                google.charts.setOnLoadCallback(drawTwoYears);
                google.charts.setOnLoadCallback(drawTop5);
                google.charts.setOnLoadCallback(drawTop10);

                var color = localStorage.getItem('cssType') == 'dark' ? 'white' : 'grey';

                //*************************************************
                function drawTop10() {
                    var data = google.visualization.arrayToDataTable([
                        ['Month', '2015'],
                        ['Back Garden', 165],
                        ['James Home', 135],
                        ['Agamin Pool', 157],
                        ['Rear Garden', 139],
                        ['Front Swimming Pool', 136]
                    
                   
                       
                    ]);

                    var options = {
                        title: 'Top 10 Largest Consumers This Month',
                        colors: ['green'],
                        titleTextStyle: { position: 'center', color: color, fontSize: '15' },
                        legend: {position: 'none'},
                        vAxis: { title: 'Unit Name', textStyle: { color: color } },
                        hAxis: { title: 'Gallon', textStyle: { color: color } },
                        backgroundColor: 'transparent',
                        is3D: true,
                     

                    };

                    var chart = new google.visualization.BarChart(document.getElementById('Top10'));
                    chart.draw(data, options);
                }
                //*************************************************
                function drawTop5() {
                    // Some raw data (not necessarily accurate)
                    var data = google.visualization.arrayToDataTable([
                         ['Month', '2015', '2016'],
                         ['1', 165, 938],
                         ['2', 135, 1120],
                         ['3', 157, 1167],
                         ['4', 139, 1110],
                         ['5', 136, 691],
                         ['6', 136, 1167],
                         ['7', 136, 691],
                         ['8', 136, 1167],
                         ['9', 136, 691],
                         ['10', 136, 691],
                         ['11', 136, 1167],
                         ['12', 136, 691]
                    ]);

                    var options = {
                        title: '2 Years Project Consumption',
                        colors: ['#e0440e', '#e6693e'],
                        titleTextStyle: {position: 'center', color: color, fontSize: '15' },
                        legend: { position: 'top', textStyle: { fontSize: '12', color: color } },
                        vAxis: { title: 'Gallon', textStyle: { color: color } },
                        hAxis: { title: 'Month', textStyle: { color: color } },
                        backgroundColor: 'transparent',
                        is3D:true,
                        seriesType: 'bars',
                        series: { 2: { type: 'line' } }
                       
                    };

                    var chart = new google.visualization.ComboChart(document.getElementById('TopFive'));
                    chart.draw(data, options);
                }
                //*************************************************
                function drawTwoYears() {
                    // Some raw data (not necessarily accurate)
                    var data = google.visualization.arrayToDataTable([
                         ['Month', '2015', '2016'],
                         ['1', 165, 17],
                         ['2', 135, 112],
                         ['3', 1157, 4167],
                         ['4', 139, 456],
                         ['5', 567, 890],
                         ['6', 28, 356],
                         ['7', 800, 67],
                         ['8', 456, 543],
                         ['9', 234, 100],
                         ['10', 345, 500],
                         ['11', 1000, 189],
                         ['12', 600, 456]
                    ]);

                    var options = {
                        title: '2 Years Project Consumption',
                        titleTextStyle: {position: 'center', color: color, fontSize: '15' },
                        legend: { position: 'top', textStyle: { fontSize: '12', color: color } },
                        vAxis: { title: 'Gallon', textStyle: { color: color } },
                        hAxis: { title: 'Month', textStyle: { color: color } },
                        backgroundColor: 'transparent',
                        is3D:true,
                        seriesType: 'bars',
                        series: { 2: { type: 'line' } }
                    };

                    var chart = new google.visualization.ComboChart(document.getElementById('TwoYears'));
                    chart.draw(data, options);
                }








            }
        };



    }
    /*******************************************************************************************************************************************************************************/

})(angular);






