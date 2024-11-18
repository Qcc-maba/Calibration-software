
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site.preview')
        .directive('season', seasonFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function seasonFactory() {
        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.site/module.settings/season.html',
            scope: {
                comm: '='
            },
            controller: ['$scope', '$locale', 'translate', '$filter', 'siteProxy', '$stateParams', function ($scope, $locale, translate, $filter, siteProxy, $stateParams) {
                //*************************************Attributs*************************************
                $scope.type = translate.clockType($locale);
                $scope.siteId = $stateParams.siteId;
                //*************************************setTime(Inner)********************************
                //function setTime(seasson) {
                //    for (var i = 0; i < $scope.seasson.listDays.length; i++) {
                //        $scope.seasson.listDays[i].StartTimeStr = $filter('date')(translate.convertUnixToTime($scope.seasson.listDays[i].startTimeSeconds), 'shortTime');
                //        $scope.seasson.listDays[i].EndTimeStr = $filter('date')(translate.convertUnixToTime($scope.seasson.listDays[i].endTimeSeconds), 'shortTime');
                //        if ($scope.seasson.listDays[i].maxDailyIrrigrationSeconds) {
                //            $scope.seasson.listDays[i].MaxMinutesStr = $scope.seasson.listDays[i].maxDailyIrrigrationSeconds / 60;
                //        } else {
                //            $scope.seasson.listDays[i].MaxMinutesStr = 0;
                //        }

                //    }
                //}
                //***************************************************************
                $scope.changeTime = function (index, param) {
                    if (param == 'start') {
                        $scope.seasson.listDays[index].startTimeSeconds = translate.stringToUnix($scope.seasson.listDays[index].StartTimeStr);
                    } else {
                        $scope.seasson.listDays[index].endTimeSeconds = translate.stringToUnix($scope.seasson.listDays[index].EndTimeStr);
                    }
                }
                //*************************************************
                $scope.changeMinutes = function (index) {

                    $scope.seasson.listDays[index].maxDailyIrrigrationSeconds = parseInt($scope.seasson.listDays[index].MaxMinutesStr) * 60;

                }
                //***********************************************************
                $scope.comm.SetCallbackDown(function (seasson) {
                    $scope.seasson = seasson;
                    //setTime();

                });
                //***********************************************************
                $scope.saveOneSesson = function () {
                    siteProxy.saveOneSesson($scope.siteId, $scope.seasson.sessionID, $scope.seasson.listDays)
                                      .success(function (data) {
                                          var s = 8;
                                      });

                }

            }],
            link: function (scope, element, attrs) {
                scope.attr = attrs.param;    //site or device

            }




        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);






