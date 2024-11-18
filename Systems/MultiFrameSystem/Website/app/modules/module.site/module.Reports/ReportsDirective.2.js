
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site.reports')
        .directive('reports', reportsFactory);
    /***************************************************************************************************************************************************************/
    function reportsFactory($log) {



        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.site/module.Reports/Reports.html',

            controller: function ($scope, $stateParams, projectProxy, baseProxy, siteProxy, $filter, user) {
            
                $scope.reportsTypes = [
                { mainType: "monthly Reports", subType: [{ name: "Monthly Consumption-Controllers" }, { name: "Monthly Consumption-Stations" }, { name: "Monthly Consumption-Programs" }] },
                { mainType: "Daily Reports", subType: [{ name: "Daily Consumption-Controllers" }, { name: "Daily Consumption-Stations" }, { name: "Daily Consumption-Programs" }] },
                { mainType: "Fertilization Reports", subType: [{ name: "Monthly Consumption With Fertilizer -Controllers" }, { name: "Daily Consumption With Fertilizer -Controllers" }, { name: "Daily Fertilization-Stations" }, { name: "Monthly Fertilization-Stations" }] }

                ]
            },
            link: function (scope, element, attrs, ngModel) {
               

            }




        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);






