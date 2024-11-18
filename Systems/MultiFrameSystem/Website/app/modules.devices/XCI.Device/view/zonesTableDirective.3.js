
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module("module.XCI.Device")
        .directive('zonesTable', zonesTableFactory);
    /********************************************************************************************************************************************************************/
    function zonesTableFactory() {


        const weekly = 'Weekly';


        return {
            restrict: 'EA',
            scope: {
                irrigationschedule: '='
            },
            templateUrl: 'app/modules.devices/XCI.Device/view/zonesTableDirectiveTemplate.html',
            controller: ['$scope', 'zoneProxy', '$locale', 'translate', '$filter', 'deviceProxy', '$state', 'mainRouter','user', function ($scope, zoneProxy, $locale, translate, $filter, deviceProxy, $state, mainRouter,user) {
                //********************************************Attribute*******************************************************

              

                $scope.locale = $locale;
                $scope.translate = translate;
                $scope.privilige = user.getSharingData().sharingData.roleModify;
                $scope.ladda = {
                    "tableLoad": false,
                    "byDay": false,
                    "byZone": false
                };
          
                $scope.type = translate.clockType($locale);
                ////*******************************************changeDeviceName****************************************************************
                $scope.changeDeviceName = function (id, newName) {
                    deviceProxy.changeDeviceName(id, newName)
                       .success(function (data) {
                           toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                       });
                }
                ////********************************************stringToUnix***************************************************************
                $scope.isAllowedTimeChanged = function (index, tb) {
                    $scope.newClickedIndex = index;
                    $scope.newClickedItem = tb;
                    var time = translate.stringToUnix(tb.firstStartTimeStr);
                    if (!isIrrigationTimeAllowed(index, time)) {
                        //popup
                        $('#timeNotAllowed').modal({
                            show: 'true'
                        })
                    } else {
                        $scope.irrigationschedule.titleDays[index].firstStartTime = time;
                        $scope.irrigationschedule.titleDays[index].numOfStartTime = 1;
                    }
                   
                  
                }
                //********************************************************************
                $scope.saveLastClickedItem = function (lastClickedItem , index) {
                    $scope.lastClickedIndex = index;
                    $scope.lastClickedItem = jQuery.extend(true, {}, lastClickedItem);
                }
                //******************************************************************
                $scope.allowAnyWay = function () {
                 
                    var time = translate.stringToUnix($scope.newClickedItem.firstStartTimeStr);
                    $scope.irrigationschedule.titleDays[$scope.newClickedIndex].firstStartTimeStr = $scope.newClickedItem.firstStartTimeStr;
                    $scope.irrigationschedule.titleDays[$scope.newClickedIndex].firstStartTime = time;
                    $scope.irrigationschedule.titleDays[$scope.newClickedIndex].numOfStartTime = 1;
                    $('#timeNotAllowed').modal('hide');
                }
                //*********************************************************************
                $scope.discardChanges = function () {

                    var time = translate.stringToUnix($scope.lastClickedItem.firstStartTimeStr);
                    $scope.irrigationschedule.titleDays[$scope.lastClickedIndex].firstStartTimeStr = $scope.lastClickedItem.firstStartTimeStr;
                    $scope.irrigationschedule.titleDays[$scope.lastClickedIndex].firstStartTime = time;
                    $scope.irrigationschedule.titleDays[$scope.lastClickedIndex].numOfStartTime = 1;
                    $('#timeNotAllowed').modal('hide');
                }
                //**************************************************
               
                //******************************************************************
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
               
                ////********************************************changeTableType**************************************************************         
                $scope.changeTableType = function (type) {
                    $scope.currentTableType = type;
                    $scope.ladda.tableLoad = true;
                    deviceProxy.changeTableType($scope.deviceId, type)
                       .success(function (data) {
                           $scope.schedualType = data.body.scheduleType;
                           if ($scope.schedualType != 'Weekly') {
                               $scope.irrigationschedule = $scope.parseSchedual(data.body);
                               mainRouter.callkey("saveScedual", $scope.irrigationschedule);
                           } else {
                               $scope.irrigationschedule = $scope.addTimeStrProperty(data.body);
                              mainRouter.callkey("saveScedual", $scope.irrigationschedule);
                           }
                           //toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                           $scope.ladda.tableLoad = false;
                       });
                }
                ////******************************************addTimeStrProperty*****************************************************************         
                $scope.addTimeStrProperty = function (irrigationschedule) {
                    for (var i = 0; i < irrigationschedule.titleDays.length; i++) {
                        var time = $filter('date')(translate.convertUnixToTime(irrigationschedule.titleDays[i].firstStartTime), 'shortTime');
                        irrigationschedule.titleDays[i]['firstStartTimeStr'] = time;
                    }
                    for (var i = 0; i < irrigationschedule.zones.length; i++) {
                        for (var j = 0; j < irrigationschedule.zones[i].days.length; j++) {
                            var min = $scope.translate.secsToMinutes(irrigationschedule.zones[i].days[j].duration);
                            irrigationschedule.zones[i].days[j]['durationStr'] = min;
                        }
                    }
                    $scope.ladda.tableLoad = false;
                    return irrigationschedule;
                }
                ////************************************************getZone***********************************************************   
                $scope.getZone = function (zoneId, zoneName) {
                    //zone irrigation sceduale
                    $scope.currentZoneName = zoneName;
                    $scope.zoneId = zoneId;
                    zoneProxy.getZoneSchedule($scope.deviceId, zoneId)
                       .success(function (data) {
                           $scope.zoneScheduleView = data.body;
                       });
                }
                //***********************************************saveIrrigationByzoneSchedule*****************************
                $scope.saveIrrigationByzoneSchedule = function () {
                    //zone irrigation sceduale
                    $scope.ladda.byZone = true;
                    zoneProxy.saveTableIrrigationByZone($scope.deviceId, $scope.zoneId,"Weekly", $scope.zoneScheduleView)
                            .success(function (data) {
                               // toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                                $scope.ladda.byZone = false;
                                $('#specificZoneModalDialog').modal('hide');
                            });
                }
                //************************************************NextZone****************************
                $scope.NextZone = function (zoneNumber) {
                    if (zoneNumber < $scope.zonesListLength) {
                        zoneNumber++;
                        zoneProxy.getZoneSchedule($scope.deviceId, zoneNumber)
                           .success(function (data) {
                               $scope.zoneScheduleView = data.body.scheduleView;
                               //run irrigation by zone directive , data.body.scheduleView must include zone name 
                               //$scope.currentZoneName = zoneName;
                               //$scope.zoneId = zoneId;
                           });
                    }
                }
                //***********************************************PrevZone*****************************
                $scope.PrevZone = function (zoneNumber) {
                    if (zoneNumber > 1) {
                        zoneNumber--;
                        zoneProxy.getZoneSchedule($scope.deviceId, zoneNumber)
                           .success(function (data) {
                               $scope.zoneScheduleView = data.body.scheduleView;
                               //run irrigation by zone directive
                           });
                    }
                }
                //**********************************************parseSchedual******************************
                $scope.parseSchedual = function (dayScheduleView) {
                    for (var i = 0; i <dayScheduleView.startTimes.length; i++) {
                        var time = $scope.translate.convertUnixToTime(dayScheduleView.startTimes[i].time);
                        var filterTime = $filter('date')(time, 'shortTime');
                        dayScheduleView.startTimes[i]['timeStr'] = filterTime;
                    }
                    for (var i = 0; i <dayScheduleView.zones.length; i++) {
                        for (var j = 0; j <dayScheduleView.zones[i].starts.length; j++) {
                            var min = $scope.translate.secsToMinutes(dayScheduleView.zones[i].starts[j].duration);
                            dayScheduleView.zones[i].starts[j]['durationStr'] = min;
                        }
                    }
                    $scope.zonesListLength = dayScheduleView.zones.length;
                    $scope.tableLoad = false;
                    return dayScheduleView;
                }
                //********************************************changeDay**********
                $scope.changeDay = function (day) {
                    //http get perDay object
                    deviceProxy.getDaySchedule($scope.deviceId, day)
                      .success(function (data) {
                          $scope.dayScheduleView = $scope.parseSchedual(data.body);
                          $scope.currentDayNum = day;
                      });
                }
                //*************************************NextDay***************************************************
                $scope.NextDay = function (day) {
                    if (day < 6) {
                        day++;
                        $scope.changeDay(day);
                    }
                    
                }
                //*************************************NextDay***************************************************
                $scope.PrevDay = function (day) {
                    if (day > 0) {
                        day--;
                        $scope.changeDay(day);
                    }
                }
                //*******************************************saveUsagePerDay*********************************
                $scope.saveUsagePerDay = function () {
                    $scope.ladda.byDay = true;
                    for (var i = 0; i < $scope.dayScheduleView.zones.length; i++) {
                        for (var j = 0; j < $scope.dayScheduleView.zones[i].starts.length; j++) {
                            $scope.dayScheduleView.zones[i].starts[j].duration = translate.minutesToSecs(parseInt($scope.dayScheduleView.zones[i].starts[j].durationStr))
                        }
                    }
                    //send the object
                    deviceProxy.saveDaySchedule($scope.deviceId,$scope.currentDayNum, $scope.dayScheduleView)
                      .success(function (data) {
                          $scope.changeTableType(1);
                          $scope.ladda.byDay = false;
                          $('#specificDayModalDialog').modal('hide');
                          toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                         
                      });
                    
                }   
                //*****************************************************************************
                $scope.goToZone = function (zoneId) {
                    fixLoadingOn("ZoneAdviser");
                    $state.go('device.XCI_device.zones.adviser', { zoneId: zoneId });
                }
                //*********************************************************************************
                mainRouter.register("refreshTable", function (data) {
                    $scope.changeTableType(null);
                });
                //*******************************************************************************
                var isIrrigationTimeAllowed = function (dayNumber,startTime) {
                    if ($scope.currentTableType == 1) {
                        for (var i = 0; i < $scope.irrigationschedule.titleDays.length; i++) {
                            if ($scope.irrigationschedule.titleDays[i].dayNumber == dayNumber) {
                                var timesArray = $scope.irrigationschedule.titleDays[i].settingsView.times;
                                for (var j = 0; j < timesArray.length; j++) {
                                    if (startTime < timesArray[j].time) {
                                        return timesArray[j - 1].allowed;
                                    }
                                    if (startTime == timesArray[j].time) {
                                        return timesArray[j].allowed;
                                    }
                                }
                            }
                        }
                    }
                    return false;
                }
            }],
            link: function (scope, element, attrs, ngModel) {
                
                scope.deviceId = attrs.device;
                scope.schedualType = scope.irrigationschedule.scheduleType;
                if (scope.schedualType == weekly) {
                    scope.currentTableType = 1;
                    scope.irrigationschedule = scope.addTimeStrProperty(scope.irrigationschedule)
                } else {
                    scope.changeTableType(scope.schedualType);
                }
               
            }
        };      
    }
              /*******************************************************************************************************************************************************************************/

})(angular);
