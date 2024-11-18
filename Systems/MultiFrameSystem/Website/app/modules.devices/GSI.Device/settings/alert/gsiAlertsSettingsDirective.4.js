(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.GSI.Device')
        .directive('alertsSettings', alertsSettingsFactory);



    function alertsSettingsFactory() {
        return {
            restrict: 'EA',

            templateUrl: 'app/modules.devices/GSI.Device/settings/alert/alertsSettings.html',

            controller: ['$scope', function ($scope) {
            //*********************************************************************************************
                $scope.alerts = {
                    isSendEmail: true,
                    table: [
                        { type: "Low Flow", stopStation: false, terminateProgram: false, openNext: true, forceCom: false },
                        { type: "hight Flow", stopStation: false, terminateProgram: false, openNext: true, forceCom: false },
                        { type: "No Waret Flow", stopStation: false, terminateProgram: false, openNext: true, forceCom: false },
                        { type: "Unexpected Flow Start", stopStation: false, terminateProgram: false, openNext: true, forceCom: false },
                        { type: "Unexpected Flow End", stopStation: false, terminateProgram: false, openNext: true, forceCom: false },
                        { type: "Communication Alert", stopStation: false, terminateProgram: false, openNext: true, forceCom: false },
                    ],
                    stopStationIrrigation: true,
                    TerminateProgram:true,
                    allowFertilizing:true,
                    forceComm:true,
                }


             

            }],
            link: function (scope, element, attrs, ngModel) {



            }




        };

    }
})(angular);