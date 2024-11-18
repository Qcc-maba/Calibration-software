
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.GSI.Device')
        .directive('generalLogs', ['$filter', generalLogsFactory]);
    /***********************************************************************************************************************************************************************/
    function generalLogsFactory() {
        return {
            restrict: 'EA',
            //require: '?ngModel',
            templateUrl: 'app/modules.devices/GSI.Device/generalLogs/generalLogs.html',

            controller: ['$scope', '$rootScope', 'siteProxy', '$filter', '$state',
                function ($scope, $rootScope, siteProxy, $filter, $state) {
                    //*********************************
                    $scope.CostomDate = {
                        'startUnix': '',
                        'endUnix': '',
                        'startStr': '',
                        'endStr': ''
                    };
                    //*********************************
                    //***********************UnixTime(Outer)****************
                    $scope.UnixTime = function (local, param) {
                        var unixInt = parseInt(local);
                        var str = $filter('date')(local, 'mediumDate');
                        if (param == 0) {
                            $scope.CostomDate.startStr = str;
                            $scope.CostomDate.startUnix = translate.fullDateStringToUnixServer(str, "00:00")
                        } else {
                            $scope.CostomDate.endStr = str;
                            $scope.CostomDate.endUnix = translate.fullDateStringToUnixServer(str, "00:00")
                        }
                    }
                    //*******************************************

                    $scope.generalLogs = [
                        { "No": 1, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08",generalLog:"SD Card", Info: false, Message: "bla bla bla" },
                        { "No": 2, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08", generalLog: "SD Card", Info: false, Message: "bla bla bla" },
                        { "No": 3, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08", generalLog: "SD Card", Info: false, Message: "bla bla bla" },
                        { "No": 4, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08", generalLog: "SD Card", Info: true, Message: "bla bla bla" },
                        { "No": 5, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08", generalLog: "SD Card", Info: true, Message: "bla bla bla" },
                        { "No": 6, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08", generalLog: "SD Card", Info: false, Message: "bla bla bla" },
                        { "No": 7, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08", generalLog: "SD Card", Info: false, Message: "bla bla bla" },
                        { "No": 8, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08", generalLog: "SD Card", Info: false, Message: "bla bla bla" },
                        { "No": 9, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08", generalLog: "SD Card", Info: false, Message: "bla bla bla" },
                        { "No": 10, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08", generalLog: "SD Card", Info: true, Message: "bla bla bla" },
                        { "No": 11, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08", generalLog: "SD Card", Info: false, Message: "bla bla bla" },
                        { "No": 12, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08", generalLog: "SD Card", Info: false, Message: "bla bla bla" },
                    ]


                    $scope.Info = [
                        { No: 1, Date: "5/1/2016 12:00:00 AM", GeneralLogs: "Unit Logs Recived Succesfully", Message: "Alert Loger . Record 1 (5/1/2016 12:00:00 AM)" },
                        { No: 2, Date: "5/1/2016 12:00:00 AM", GeneralLogs: "Unit Logs Recived Succesfully", Message: "Alert Loger . Record 1 (5/1/2016 12:00:00 AM)" },
                        { No: 3, Date: "5/1/2016 12:00:00 AM", GeneralLogs: "Unit Logs Recived Succesfully", Message: "Alert Loger . Record 1 (5/1/2016 12:00:00 AM)" },
                        { No: 4, Date: "5/1/2016 12:00:00 AM", GeneralLogs: "Unit Logs Recived Succesfully", Message: "Alert Loger . Record 1 (5/1/2016 12:00:00 AM)" },
                        { No: 5, Date: "5/1/2016 12:00:00 AM", GeneralLogs: "Unit Logs Recived Succesfully", Message: "Alert Loger . Record 1 (5/1/2016 12:00:00 AM)" },
                        { No: 6, Date: "5/1/2016 12:00:00 AM", GeneralLogs: "Unit Logs Recived Succesfully", Message: "Alert Loger . Record 1 (5/1/2016 12:00:00 AM)" },
                        { No: 7, Date: "5/1/2016 12:00:00 AM", GeneralLogs: "Unit Logs Recived Succesfully", Message: "Alert Loger . Record 1 (5/1/2016 12:00:00 AM)" },
                        { No: 8, Date: "5/1/2016 12:00:00 AM", GeneralLogs: "Unit Logs Recived Succesfully", Message: "Alert Loger . Record 1 (5/1/2016 12:00:00 AM)" },
                        { No: 9, Date: "5/1/2016 12:00:00 AM", GeneralLogs: "Unit Logs Recived Succesfully", Message: "Alert Loger . Record 1 (5/1/2016 12:00:00 AM)" },
                    ]


                }],
            link: function (scope, element, attrs) {

                //if (!ngModel) return;
                //ngModel.$render = function () {

                //    scope.deviceId = ngModel.$viewValue;


                //};

            }

        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);






