

(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.XCI.zones')
        .directive('zonesCategories', zonesCategoriesFactory);
    /***********************************************************************************************************************************************************************/
    function zonesCategoriesFactory() {
        return {
            restrict: 'EA',
            templateUrl: 'app/modules.devices/XCI.Device/module.XCI.zone/zonesCategories.html',

            controller: ['$scope', 'zoneProxy', 'directiveComm', '$state', 'mainRouter', '$stateParams', '$filter', 'onlineProvider', 'deviceProxy', function ($scope, zoneProxy, directiveComm, $state, mainRouter, $stateParams, $filter, onlineProvider, deviceProxy) {
                //**************************************Attribute******************************
                const MAX_DIFF_ZONES_UPDATE = 20;
                var precent;
                var fill;
                $scope.param = 1;
                $scope.ladda = {
                    "flow": false,
                    "settings": false,
                    "schedule": false,
                    "acceptSeggestion": false,
                    "saveWizard": false,
                    "uploadFile":false
                }
                $scope.refreshTable = 0;
                $scope.deviceId = $stateParams.deviceId;
                $scope.zoneId = $stateParams.zoneId;
                $scope.scheduleConnector = directiveComm.CreateConnector();
                $scope.OddEvenConnector = directiveComm.CreateConnector();
                $scope.adviserConnector = directiveComm.CreateConnector();
                var zoneEvent = (4000 + parseInt($scope.zoneId)).toString();
                var OnlineEvents = [zoneEvent];
                //**************************************Functions******************************
                function parseSecondsToStringDate(sec) {
                    var seconds = Math.floor(sec % 60).toString();
                    var minutes = Math.floor((sec / 60) % 60).toString();
                    var hours = Math.floor((sec / (60 * 60)) % 24).toString();
                    if (seconds.length == 1) {
                        seconds = '0' + seconds;
                    }
                    if (minutes.length == 1) {
                        minutes = '0' + minutes;
                    }
                    if (hours.length == 1) {
                        hours = '0' + hours;
                    }
                    return hours + ':' + minutes + ':' + seconds
                }
                //****************************************************************************
                function onlineCBfuncZonePage(data) {
                    calcZoneTimeLeft(data);
                }
                //**************************************************************************************
                function calcZoneTimeLeft(event) {
                    var timeLeft_Sec = event.timeUnit == 'minute' ? event.timeLeft * 60 : event.timeLeft;

                    var serverUTC = new Date().getTime() + onlineProvider.getDiffUTC();  // server current time
                    var deffBetweenLastUbdateToEventTime = (serverUTC - event.lastUpdate);
                    var newTimeLeft = timeLeft_Sec - (deffBetweenLastUbdateToEventTime / 1000);  //ex' last update 8:00:00 time left 7 min  ; now 08:00:30 ---> deffBetweenLastUbdateToEventTime = 30   ---> newTimeLeft = 6:30 minutes
                    if (newTimeLeft < 2) {
                        $scope.timeLeftStr = null;
                        return;
                    }

                    //calc the diff between the two:
                    //      a. local time left (timeLeft_Sec changed by timer)
                    //      b. server time left (newTimeLeft, calculted using the onlineProvider.getDiffUTC())
                    var diffTimeLeft = $scope.timeLeftStr ? Math.abs(newTimeLeft - $scope.timeLeft_Sec) : MAX_DIFF_ZONES_UPDATE + 1;
                    if (diffTimeLeft > MAX_DIFF_ZONES_UPDATE) {
                        $scope.timeLeft_Sec = newTimeLeft;
                        $scope.timeLeftStr = parseSecondsToStringDate(newTimeLeft);
                    }
                }
                //****************************************************************************
                function zoneIntervalFunction() {
                    if ($scope.timeLeftStr) {
                        if ($scope.timeLeft_Sec > 2) {
                            $scope.timeLeft_Sec--;
                            $scope.timeLeftStr = parseSecondsToStringDate($scope.timeLeft_Sec);
                        } else {
                            $scope.timeLeftStr = null;
                        }
                    }
                }
                //************************************************SetCallbackUp(scheduleConnector)******************************
                $scope.adviserConnector.SetCallbackUp(function (obj) {
                    //send to server accept suggistion
                    var promise = {
                        callback: null,
                        success: function (callback) {
                            this.callback = callback;
                        }

                    };
                    if (obj.service == "AcceptSuggestions") {
                        zoneProxy.AcceptSuggestions($scope.deviceId, $scope.zoneId, obj)//send to server accept suggistion servise not exists
                             .success(function (data) {
                                 promise.callback();
                                 //$scope.AcceptSuggestions(obj.suggestions);
                                 // buildObject(data);
                             });
                        
                        
                    } else { //save categories changes
                        //send to server saveCategories servise not exists
                        //zoneProxy.saveCategories($scope.deviceId, $scope.zoneId, obj)
                        //    .success(function (data) {
                        //        promise.callback();
                              
                        //    });
                        zoneProxy.AcceptSuggestions($scope.deviceId, $scope.zoneId, obj)//send to server accept suggistion servise not exists
                             .success(function (data) {
                                 promise.callback();
                                 //$scope.AcceptSuggestions(obj.suggestions);
                                 // buildObject(data);
                             });
                    }
                    return promise;
                   
                });
                //********************************************************************
                $scope.OddEvenConnector.SetCallbackUp(function (data) {
                    $scope.scheduleView.totalWeeklyMinutes = data;
                });
                //************************************************SetCallbackUp(scheduleConnector)******************************
                $scope.scheduleConnector.SetCallbackUp(function () {
                    var totalDays = [];
                    var totalMinutes = 0;
                    for (var i = 0; i < $scope.scheduleView.rows.length; i++) {
                        for (var j = 0; j < $scope.scheduleView.rows[i].days.length; j++) {
                            totalMinutes += parseInt($scope.scheduleView.rows[i].days[j].duration == null? 0 : $scope.scheduleView.rows[i].days[j].duration /60);
                            totalDays[j] = (totalDays[j] || 0) + parseInt($scope.scheduleView.rows[i].days[j].duration || 0);
                        }
                    }
                    var totalDaysCount = 0;
                    for (var i = 0; i < totalDays.length; i++) {
                        totalDaysCount += totalDays[i] > 0 ? 1 : 0;
                    }
                    $scope.scheduleView.totalWeeklyMinutes = totalMinutes;
                    $scope.scheduleView.totalWeeklyDays = totalDaysCount;
                });
                //************************************************buildObject******************************
                var buildObject = function (data) {
                    $scope.zone = data.body;
                    $scope.zoneNumber = data.body.zoneNumber;
                    $scope.categoriesView = data.body.categoriesView;
                  //  $scope.irrigationSuggestions = data.body.irrigationSuggestions;
                  //  $scope.acceptRecommendation = data.body.irrigationSuggestions.isAccepted;
                    $scope.scheduleView = data.body.scheduleView;
                    $scope.settings = data.body.settings;
                    $scope.flowSensorSettings = data.body.flowSensorSettings;
                    $scope.$emit('zoneLoad');
                    onlineProvider.registerDevice(OnlineEvents, $scope.deviceId, 'zoneOnline', onlineCBfuncZonePage);
                    fixLoadingOff();
                }
                //************************************************getZoneDetails******************************
                $scope.getZoneDetails = function (controllerId, zoneId) {
                    zoneProxy.getZoneDetails(controllerId, zoneId)
                   .success(function (data) {
                       buildObject(data);
                   });
                }
                //************************************************AcceptSuggestions******************************
                $scope.AcceptSuggestions = function (suggestions) {
                   
                    zoneProxy.AcceptSuggestions($scope.deviceId, $scope.zoneId, suggestions)
                       .success(function (data) {
                           buildObject(data);
                         
                       });
                }
                //************************************************saveTableIrrigationByZone******************************
                $scope.saveTableIrrigationByZone = function (form) {
                    if (form) {

                
                    $scope.ladda.schedule = true;
                    zoneProxy.saveTableIrrigationByZone($scope.deviceId, $scope.zoneId, $scope.scheduleView.scheduleType, $scope.scheduleView)
                            .success(function (data) {

                                 mainRouter.callkey("showRecomendationEvent", {});
                                 $scope.ladda.schedule = false;
                                 toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                            }).error(function (data, status, headers, config) {
                                toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));

                            });
                    } else {
                        toastr.error($filter('translate')('toastrErrForms'), $filter('translate')('Error'));
                    }
                }
                //************************************************saveSettings******************************
                $scope.saveSettings = function (form) {
                    if (form) {

                  
                        $scope.ladda.settings = true;
                        zoneProxy.saveSettings($scope.deviceId, $scope.zoneId, $scope.settings)
                       .success(function (data) {
                           toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                           $scope.ladda.settings = false;
                       }).error(function (data, status, headers, config) {
                           toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));

                       });
                    } else {
                        toastr.error($filter('translate')('toastrErrForms'), $filter('translate')('Error'));
                    }
                }
                //************************************************SaveflowSensorSettings******************************
                $scope.SaveflowSensorSettings = function (form) {
                    if (form) {
                        $scope.ladda.flow = true;
                        zoneProxy.flowSensorSettings($scope.deviceId, $scope.zoneId, $scope.flowSensorSettings)
                       .success(function (data) {
                           toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                           $scope.ladda.flow = false;
                       }).error(function (data, status, headers, config) {
                           toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));

                       });
                    } else {
                        toastr.error($filter('translate')('toastrErrForms'), $filter('translate')('Error'));
                    }
                }
          
                //************************************************getZoneSaggestionWizard******************************
                $scope.getZoneSaggestionWizard = function () {
                    zoneProxy.getZoneSaggestionWizard($scope.deviceId, $scope.zoneId).success(function (data) {
                        $scope.categories = buildingZones(data.body);
                        var obj = {
                            categories: $scope.categories,
                            suggestions: $scope.irrigationSuggestions
                        }
                        $scope.adviserConnector.CallbackDown(obj);
                        
                    });

                }
                //*****************************************************
                $scope.changeZoneName = function (sn, zoneId, name) {
                    zoneProxy.changeZoneName(sn, zoneId, name)
                    .success(function (data) {
                        toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                    }).error(function (data, status, headers, config) {
                        toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
                    });
                }
                //*****************************************************************************************
                function stringTimeToSeconds(strTime) {
                    if (!strTime) {
                        return 0;
                    }
                    return parseInt(strTime.Hours) * 3600 + parseInt(strTime.Minutes) * 60 + parseInt(strTime.Seconds);
                }
                //****************************************************
                $scope.startManualOperation = function (time) {
                    deviceProxy.manualZoneOperationOnline($scope.deviceId, $scope.zoneId, stringTimeToSeconds(time))
                        .success(function (data, status, headers, config) {
                       
                        }).error(function (data, status, headers, config) {

                        });
                    //*****************
                    $('#setZoneTimeZonePage').modal('hide');
                }
                //***********************************************
                function buildingZones(SuggetionsTypes) {
                    var oneZone = {
                        zoneName: "",
                        zoneId: 0,
                        acceptSuggestions: false,
                        plantType: {
                            selected: {},
                            restType: {},
                            advisorTypeID:10
                        },
                        slopeType: {
                            selected: {},
                            restType: {},
                            advisorTypeID: 10
                        },
                        soilType: {
                            selected: {},
                            restType: {},
                            advisorTypeID:10
                        },
                        sprinklerType: {
                            selected: {},
                            restType: {},
                            advisorTypeID: 10
                        },
                        sunExposureType: {
                            selected: {},
                            restType: {},
                            advisorTypeID: 10
                        }

                    }
                    for (var key1 in SuggetionsTypes) {
                        if (SuggetionsTypes.hasOwnProperty(key1)) {
                            var Type = SuggetionsTypes[key1];
                            if (Type.optionalValues) {
                                oneZone[key1].restType = jQuery.extend(true, {}, Type.optionalValues);
                                oneZone[key1].advisorTypeID = Type.advisorTypeID;
                                for (var i = 0; i < Type.optionalValues.length; i++) {
                                    if (Type.optionalValues[i].isSelected) {
                                        oneZone[key1].selected = jQuery.extend(true, {}, Type.optionalValues[i]);

                                        break;
                                    }
                                }
                            }
                        }
                    }
                    return oneZone;
                  


                   
                }

                //****************************************************
                mainRouter.register("refreshZonePage", function (data) {
                    zoneProxy.getZoneSchedule($scope.deviceId, $scope.zoneId)
                       .success(function (data) {
                           $scope.scheduleView = data.body;
                           $scope.refreshTable++;
                           $scope.$apply();
                       });
                });
                //***********************************************************
                onlineProvider.registerIntervalCallback(zoneIntervalFunction);

                //*********************************zoneImage******************************
                function resetLoading() {

                    $('.zoneFixLoadingImage').css({ 'display': 'none' });
                    fill.width('0');
                    precent.html(0 + "%");


                }
                //*******************************************************************
                $scope.myANCallback = function (val) {

                    $('.zoneFixLoadingImage').css({ 'display': 'block' });
                    precent = $('.loadingContainer .precent');
                    fill = $('.loadingContainer .loadingBar .fill');
                };
                //***************************************************************
                $scope.myCallback = function (valueFromDirective) {
                    $scope.ladda.uploadFile = false;
                    if (valueFromDirective.body) {

                        $scope.zone.imageURI = valueFromDirective.body;
                        $scope.$apply();
                       resetLoading();
                       toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                    } else {
                        resetLoading();
                        toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
                    }

                };
                //************************************************************
                $scope.progress = function (val) {  // full width = 216px
                    precent.html(parseInt(val) + "%");
                    var currentWidth = parseInt((val / 100) * 216);
                    fill.width(currentWidth);
                    $scope.$apply();

                };
                //**************************************************
            }],
            //************************************************link***************************************
            link: function (scope, element, attrs, ngModel) {
                scope.getZoneDetails(scope.deviceId, scope.zoneId)
                scope.getZoneSaggestionWizard();
            }
        };//return
    }
})(angular);
