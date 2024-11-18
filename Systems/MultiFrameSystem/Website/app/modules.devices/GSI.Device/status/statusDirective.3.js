
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.GSI.Device')
        .directive('status', ['$filter', statusFactory]);
    /***********************************************************************************************************************************************************************/
    function statusFactory($filter) {
        return {
            restrict: 'EA',
            templateUrl: 'app/modules.devices/GSI.Device/status/status.html',

            controller: ['$scope', '$rootScope', 'siteProxy', '$filter', '$state',
                function ($scope, $rootScope, siteProxy, $filter, $state) {
                    $scope.isLogAlert = false;
                    $scope.irrigation = [
                        { No: 1, Date: "1.1.1990", StartTime: "07:00", EndTime: "08:45", Program: "Program-A",Station:"10", RunTime: "1:45", WaterQuantity: "", AverageFlow: "0.0 m3/h", FertilizerQuantity: "", Comment: "" },
                        { No: 2, Date: "1.1.1990", StartTime: "07:00", EndTime: "08:45", Program: "Program-A", Station: "10", RunTime: "1:45", WaterQuantity: "", AverageFlow: "0.0 m3/h", FertilizerQuantity: "", Comment: "" },
                        { No: 3, Date: "1.1.1990", StartTime: "07:00", EndTime: "08:45", Program: "Program-A", Station: "10", RunTime: "1:45", WaterQuantity: "", AverageFlow: "0.0 m3/h", FertilizerQuantity: "", Comment: "" },
                        { No: 4, Date: "1.1.1990", StartTime: "07:00", EndTime: "08:45", Program: "Program-A", Station: "10", RunTime: "1:45", WaterQuantity: "", AverageFlow: "0.0 m3/h", FertilizerQuantity: "", Comment: "" },
                        { No: 5, Date: "1.1.1990", StartTime: "07:00", EndTime: "08:45", Program: "Program-A", Station: "10", RunTime: "1:45", WaterQuantity: "", AverageFlow: "0.0 m3/h", FertilizerQuantity: "", Comment: "" },
                        { No: 6, Date: "1.1.1990", StartTime: "07:00", EndTime: "08:45", Program: "Program-A", Station: "10", RunTime: "1:45", WaterQuantity: "", AverageFlow: "0.0 m3/h", FertilizerQuantity: "", Comment: "" },
                        { No: 7, Date: "1.1.1990", StartTime: "07:00", EndTime: "08:45", Program: "Program-A", Station: "10", RunTime: "1:45", WaterQuantity: "", AverageFlow: "0.0 m3/h", FertilizerQuantity: "", Comment: "" },
                        { No: 8, Date: "1.1.1990", StartTime: "07:00", EndTime: "08:45", Program: "Program-A", Station: "10", RunTime: "1:45", WaterQuantity: "", AverageFlow: "0.0 m3/h", FertilizerQuantity: "", Comment: "" },
                        { No: 9, Date: "1.1.1990", StartTime: "07:00", EndTime: "08:45", Program: "Program-A", Station: "10", RunTime: "1:45", WaterQuantity: "", AverageFlow: "0.0 m3/h", FertilizerQuantity: "", Comment: "" },
                        { No: 10, Date: "1.1.1990", StartTime: "07:00", EndTime: "08:45", Program: "Program-A", Station: "10", RunTime: "1:45", WaterQuantity: "", AverageFlow: "0.0 m3/h", FertilizerQuantity: "", Comment: "" }

                    ]

                    $scope.alerts = [
                        { No: 1, Date: "1.1.1990  12:55:00",AlertType:"No Water Flow", Program: "Program-A", Station: "10", ActualFlow: "0.0 m3/h", NominalFlow: "0.0 m3/h", WatherQuantity: "", Comment: "" },
                        { No: 2, Date: "1.1.1990  12:55:00", AlertType: "No Water Flow", Program: "Program-A", Station: "10", ActualFlow: "0.0 m3/h", NominalFlow: "0.0 m3/h", WatherQuantity: "", Comment: "" },
                        { No: 3, Date: "1.1.1990  12:55:00", AlertType: "No Water Flow", Program: "Program-A", Station: "10", ActualFlow: "0.0 m3/h", NominalFlow: "0.0 m3/h", WatherQuantity: "", Comment: "" },
                        { No: 4, Date: "1.1.1990  12:55:00", AlertType: "No Water Flow", Program: "Program-A", Station: "10", ActualFlow: "0.0 m3/h", NominalFlow: "0.0 m3/h", WatherQuantity: "", Comment: "" },
                        { No: 5, Date: "1.1.1990  12:55:00", AlertType: "No Water Flow", Program: "Program-A", Station: "10", ActualFlow: "0.0 m3/h", NominalFlow: "0.0 m3/h", WatherQuantity: "", Comment: "" },
                        { No: 6, Date: "1.1.1990  12:55:00", AlertType: "No Water Flow", Program: "Program-A", Station: "10", ActualFlow: "0.0 m3/h", NominalFlow: "0.0 m3/h", WatherQuantity: "", Comment: "" },
                        { No: 7, Date: "1.1.1990  12:55:00", AlertType: "No Water Flow", Program: "Program-A", Station: "10", ActualFlow: "0.0 m3/h", NominalFlow: "0.0 m3/h", WatherQuantity: "", Comment: "" },
                        { No: 8, Date: "1.1.1990  12:55:00", AlertType: "No Water Flow", Program: "Program-A", Station: "10", ActualFlow: "0.0 m3/h", NominalFlow: "0.0 m3/h", WatherQuantity: "", Comment: "" }
                        


                    ]


                    //*******************************
                    
                    $('#GsiDeviceStatusdragButton').mousedown(function (e) {
                        e.preventDefault();

                        Statusdragbar = true;

                    });

                }],
            link: function (scope, element, attrs, ngModel) {

               

            }

        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);






