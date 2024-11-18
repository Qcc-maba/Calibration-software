
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module("module.XCI.Device")
        .directive('zonesIrrigationByDay', zonesIrrigationByDayFactory);
    /********************************************************************************************************************************************************************/
    function zonesIrrigationByDayFactory() {
        return {
            restrict: 'EA',
            require: '?ngModel',
            scope: {
                scheduleview: '='
            },
            templateUrl: 'app/modules.devices/XCI.Device/view/byDay.html',
            controller: ['$scope', '$locale', 'translate', '$state', function ($scope, $locale, translate, $state) {
                const maxStarts = 4;
                $scope.locale = $locale;
                $scope.translate = translate;
                $scope.v = $scope.scheduleview;
                //*********************************************************************************************************
                $scope.type = translate.clockType($locale);
                //**************************************************stringToUnix*******************************************
                $scope.stringToUnix = function (index, str) {
                    var time = translate.stringToUnix(str);
                    $scope.scheduleview.startTimes[index].time = time;
                }
                //*********************************************************************
                $scope.isAllowedTimeChanged = function (tb,index) {
                    $scope.newClickedItem = tb;
                    $scope.newClickedIndex = index;
                    var time = translate.stringToUnix(tb.timeStr);
                    if (!isIrrigationTimeAllowed(time)) {
                   
                        $('#timeNotAllowed').modal({
                            show: 'true'
                        })
                 
                    } else {
                        $scope.scheduleview.startTimes[index].time = time;
                     
                    }
                }
                //******************************************************************
                $scope.allowAnyWay = function () {

                     var time = translate.stringToUnix($scope.newClickedItem.timeStr);
                     $scope.scheduleview.startTimes[$scope.newClickedIndex].timeStr = $scope.newClickedItem.timeStr;
                     $scope.scheduleview.startTimes[$scope.newClickedIndex].time = time;
                    $('#timeNotAllowed').modal('hide');
                }
                //*********************************************************************
                $scope.discardChanges = function () {

                    var time = translate.stringToUnix($scope.lastClickedItem.timeStr);
                    $scope.scheduleview.startTimes[$scope.lastClickedIndex].timeStr = $scope.lastClickedItem.timeStr;
                    $scope.scheduleview.startTimes[$scope.lastClickedIndex].time = time;
                    $('#timeNotAllowed').modal('hide');
                }
                //*************************************************************************
                $scope.bodyValChange = function (tb) {
                    if (tb.durationStr !== '0' && tb.durationStr.isNumeric() && !tb.durationStr == '') {
                        tb.durationStr = parseInt(tb.durationStr, 10);
                        var num = tb.durationStr * 60;
                        if (num <= MAXIRRIGATION_TIME * 60) {
                            tb.duration = num;
                        } else {
                            tb.durationStr = MAXIRRIGATION_TIME;
                            tb.duration = MAXIRRIGATION_TIME * 60;
                        }
                    } else if (tb.durationStr == '') {
                        tb.durationStr = 0;
                        tb.duration = 0;
                    }

                    else {
                        tb.durationStr = 0;
                        tb.duration = 0;
                        return;
                    }

                    
                }
                //*************************************************addTimeCol**********************************************
                $scope.addTimeCol = function () {
                    if ($scope.scheduleview.startTimes.length < maxStarts) {
                        var obj = {};
                        if ($scope.type == "AMPM") {
                            obj.timeStr = '09:00AM';
                        }
                        else {
                            obj.timeStr = '09:00';
                        }
                        obj.time = translate.stringToUnix("09:00AM")

                        $scope.scheduleview.startTimes.unshift(obj)
                        for (var i = 0; i < $scope.scheduleview.zones.length; i++) {
                            var obj = {};
                            obj.duration = 0,
                            obj.quantity = 0;
                            obj.durationStr = '';
                            $scope.scheduleview.zones[i].starts.unshift(obj);

                        }
                    }
              

                }
                //**************************************************delTimeCol*********************************************
                $scope.delTimeCol = function (Index) {
                    if ($scope.scheduleview.startTimes.length > 1) {
                        $scope.scheduleview.startTimes.splice(Index, 1);
                        for (var i = 0; i < $scope.scheduleview.zones.length; i++) {

                            $scope.scheduleview.zones[i].starts.splice(Index, 1);

                        }
                    }
                    
                  
                  
                

                }
                //*****************************************************************************************************
                $scope.goToZone = function (zoneId) {
                    fixLoadingOn("ZoneOddAdviser");
                    $state.go('device.XCI_device.zones.adviser', { zoneId: zoneId });
                }
                //*********************************************************************************************************
                $scope.saveLastClickedItem = function (lastClickedItem, index) {
                    if ($scope.scheduleview.scheduleType == 'Weekly') {
                        $scope.lastClickedIndex = index;
                        $scope.lastClickedItem = jQuery.extend(true, {}, lastClickedItem);
                    }
                }
                //***********************************************************************************************

                var isIrrigationTimeAllowed = function (time) {
                    if ($scope.scheduleview.scheduleType == 'Weekly') {
                        var times = $scope.scheduleview.day.settingsView.times;
                        for (var i = 0; i < times.length; i++) {
                            
                           
                            if (time < times[i].time) {
                                return times[i - 1].allow;
                                }
                            if (time == times[i].time) {
                                return times[j].allow;
                             
                                 }
                        }
                    }
                    return false;
                }


            }],
            link: function (scope, element, attrs, ngModel) {
              
                if (!ngModel) return; // do nothing if no ng-model
                ngModel.$render = function () {
                    scope.theDayNum = ngModel.$viewValue;
                   
                };
            }
        };//return
    }
})(angular);
