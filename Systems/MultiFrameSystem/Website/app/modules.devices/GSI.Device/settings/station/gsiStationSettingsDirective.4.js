(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.GSI.Device')
        .directive('stationSettings', stationSettingsFactory);



    function stationSettingsFactory() {
        return {
            restrict: 'EA',

            templateUrl: 'app/modules.devices/GSI.Device/settings/station/stationSettings.html',

            controller: ['$scope', function ($scope) {
             
                //*********************************************************************************************
                $scope.stations = {
                    tableHead: [  { id: 1, name: "S1" }
                                , { id: 2, name: "S2" }
                                , { id: 3, name: "S3" }
                                , { id: 4, name: "S4" }
                                , { id: 5, name: "S5" }
                                , { id: 6, name: "S6" }
                                , { id: 7, name: "S7" }
                                , { id: 8, name: "S8" }
                                , { id: 9, name: "S9" }
                                , { id: 10, name: "S10" }
                                , { id: 11, name: "S11" }
                                , { id: 12, name: "S12" }
                                , { id: 13, name: "S13" }
                                , { id: 14, name: "S14" }
                                , { id: 15, name: "S15" }
                                , { id: 16, name: "S16" }
                                , { id: 17, name: "S17" }
                                , { id: 18, name: "S18" }
                                , { id: 19, name: "S19" }
                                , { id: 20, name: "S20" }
                                , { id: 21, name: "S21" }
                                , { id: 22, name: "S22" }
                                , { id: 23, name: "S23" }
                                , { id: 24, name: "S24" }
                           
                    ],
                    allStations: [
                        { value: "Active" }
                      , { }
                      , { }
                      , { des: "Copy value from last irrigation" }
                      , { des: "Higher Than", value: 30, units: "%" }
                      , { des: "For All Stations", value: 1, units: "Min" }
                      , { des: "Less Than", value: 27, units: "%" }
                      , { des: "For All Stations", value: 30, units: "Min" }
                      , { des: "For All Stations", value: 30, units: "Min" }
                      , {}
                      , {}
                    ],
                    tableRow: [
                        {
                            categorey: "Status",
                            list: [
                              { value: "Active" }, { value: "Off" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }
                            ]
                        },
                        {
                            categorey: "Station Name",
                            list: [
                              { value: "S1" }, { value: "S2" }, { value: "S3" }, { value: "S4" }, { value: "S5" }, { value: "S6" }, { value: "S7" }, { value: "S8" }, { value: "S9" }, { value: "S10" }, { value: "S11" }, { value: "S12" }, { value: "S13" }, { value: "S14" }, { value: "S15" }, { value: "S16" }, { value: "S17" }, { value: "S18" }, { value: "S19" }, { value: "S20" }, { value: "S21" }, { value: "S22" }, { value: "S23" }, { value: "S24" }
                            ]
                        },
                         {
                             categorey: "Last Flow Rate",
                             list: [
                               { value: 180, unit: "m3/h" }, { value: 0, unit: "m3/h" }, { value: 0, unit: "m3/h" }, { value: 58, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 0, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }
                             ]
                         },
                        
                        
                         {
                             categorey: "set Nominimal Flow (m3/h)",
                             list: [
                               { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }
                             ]
                         }
                         ,
                         {
                             categorey: "High Flow Alert (%)",
                             list: [
                               { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }
                             ]
                         }
                         ,
                         {
                             categorey: "Delay Before Low Flow Alert (min)",
                             list: [
                               { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }
                             ]
                         }
                         ,
                         {
                             categorey: "Line Fill Time (min)",
                             list: [
                               { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }
                             ]
                         }
                         ,
                         {
                             categorey: "Area Size (m2)",
                             list: [
                               { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }
                             ]
                         }
                         ,
                         {
                             categorey: "Precipitation Rate (mm/hr)",
                             list: [
                               { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }
                             ]
                         }


                    ],
                    stopStationIrrigation: true,
                    TerminateProgram: true,
                    allowFertilizing: true,
                    forceComm: true,
                }




            }],
            link: function (scope, element, attrs, ngModel) {



            }




        };

    }
})(angular);
