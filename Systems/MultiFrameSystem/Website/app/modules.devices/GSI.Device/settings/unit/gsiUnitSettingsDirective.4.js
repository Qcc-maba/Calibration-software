(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.GSI.Device')
        .directive('unitSettings', unitSettingsFactory);



    function unitSettingsFactory() {
        return {
            restrict: 'EA',

            templateUrl: 'app/modules.devices/GSI.Device/settings/unit/unitSettings.html',

            controller: ['$scope', function ($scope) {
                //*********************************************************************************************

                $scope.unitState = {
                    state:'Active'
                }

                $scope.generalSettings = {
                    
                    weekly: {
                        days: [{ num: 0, state: true }, { num: 1, state: false }, { num: 2, state: true }, { num: 3, state: true }, { num: 4, state: true }, { num: 5, state: true }, { num: 6, state: true }]
                    },
                    nonIrrigationDates: [{ date: 1452178120549 }, { date: 1452067381081 }],
                    rainSensor:true
                }

                $scope.waterMeter = {
                    useWaterMeter: true,
                    size: ["1 Liter", "10 Liter", "100 Liter", "1 m3", "10 m3"],
                    choosenSize: "1 Liter",
                    waitBefor: 20,
                    enableLeack: true,
                    pulseAlert:5
                }

                $scope.fertilizer = {
                    useFertilizer: true,
                    pumpType: "fertilizer",
                    rate: 6,
                    stroke: 2,
                    fertilizerAlert: true,
                    size: ["1 cc", "10 cc", "100 cc", "1 liter", "10 liter"],
                    choosenSize: "1 cc",
                    useCustomValue: false,
                    customValue: 3,
                    injectionM: "proportional",
                    noFertilizerFlowAlert: 180,
                    fertilizerLeakage: true,
                    numberOfPulse:20
                }
                $scope.season = {
                    start: 1452178120549,
                    end: 1452178120549,
                    budget: 0,
                    total: false,
                    season:false,
                    month:false,
                    messages:false,
                    unexpectedFlow:false,
                    powerControl:false
                    
                }
                $scope.advanced = {
                    mUnit: "metric",
                    mList: ["m2", "Dunam", "hectare"],
                    iList: ["ft2", "Acres"],
                    showMlist: true,
                    mCurrentType: "m2",
                    iCurrentType: "ft2",
                    mOpen: "station",
                    mOpenDelay:5,
                    mClose: "master",
                    mCloseDelay: 5,
                    pStationOverlapOrDelay: "overflap",
                    pStationOverlapOrDelaySecs:5

                    
                }
                //*********************************************************************************************
                $scope.advancedSetAreaUnit = function (m, s) {
                    if (m == 'metric') {
                        $scope.advanced.mCurrentType = s;
                    } else {
                        $scope.advanced.iCurrentType = s;
                    }
                }
                //*********************************************************************************************
                $scope.setAdvancedMeasurementUnit = function (m) {
                    if (m == 'metric') {
                        $scope.advanced.showMlist = true;
                    } else {
                        $scope.advanced.showMlist = false;
                    }

                }
                //********************************************************************************************
                $scope.waterMeterSetPulseSize = function (s) {
                    $scope.waterMeter.choosenSize = s;
                }
                //********************************************************************************************
                $scope.fertilizerSetPulseSize = function (s) {
                    $scope.fertilizer.choosenSize = s;
                }
                //*********************************************************************************************
                $scope.deleteNonIrrigationDates = function () {
                    $scope.generalSettings.nonIrrigationDates = [];
                }
                //*********************************************************************************************
                $scope.chooseNewDate = function (date) {
                    //check if date diffrent and than push to array
                    var obj = {
                        date: date
                    }
                    $scope.generalSettings.nonIrrigationDates.push(obj);
                }
                //**********************************************************************************************

            }],
            link: function (scope, element, attrs, ngModel) {



            }




        };

    }
})(angular);