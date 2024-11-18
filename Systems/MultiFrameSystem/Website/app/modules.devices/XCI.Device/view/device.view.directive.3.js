
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.XCI.Device')
        .directive('deviceView', deviceViewFactory);
    /*********************************************************************************************************************************************************/
    function deviceViewFactory() {
        return {
            restrict: 'EA',
            require: '?ngModel',
            templateUrl: 'app/modules.devices/XCI.Device/view/device.view.html',
            controller: ['$scope', 'deviceProxy', 'zoneProxy', '$locale', 'translate', '$filter', '$state', 'directiveComm', 'mainRouter','user', function ($scope, deviceProxy, zoneProxy, $locale, translate, $filter, $state, directiveComm, mainRouter,user) {
                //********************************************Attributes*****************************************************
                $scope.privilige = user.getSharingData().sharingData.roleModify;
                $scope.ladda = {
                    "scheduleView": false,
                    "settings": false,
                    "rainSensorSettings": false,
                    "irrigatingSettings": false,
                    "flowSensorSettings": false,
                    "SaveAlerts": false,
                    "SaveAlertsModal": false,
                    "deleteCtrl": false
                };
          
                $scope.scheduleConnector = directiveComm.CreateConnector();
                $scope.daySettingConnector = directiveComm.CreateConnector();
                $scope.scheduleConnector.SetCallbackUp(function () {
                });
                $scope.locale = $locale;
                $scope.translate = translate;
                $scope.type = translate.clockType($locale);
                //**************************************getViewPage(Outer)*****************
                $scope.getViewPage = function (deviceId) {
                    deviceProxy.getViewPage(deviceId)
                       .success(function (data) {
                           data = data.body;
                           $scope.allObject = data.deviceSettingsView;
                           $scope.settings = data.deviceSettingsView.deviceSettings;
                           $scope.displaySettings = data.deviceSettingsView.displaySettings;
                           $scope.irrigatingSettings = data.deviceSettingsView.irrigatingSettings;
                           $scope.rainSensorSettings = data.deviceSettingsView.rainSensorSettings;
                           $scope.flowSensorSettings = data.deviceSettingsView.flowSensorSettings;
                           $scope.deviceAlertsSettings = data.deviceSettingsView.alertThresholdSettings;
                           $scope.irrigationSchedule = data.deviceSettingsView.irrigationSchedule;
                           $scope.zonesListLength = data.deviceSettingsView.irrigationSchedule.zones.length;
                           $scope.settings.holdUntilStr = $filter('date')($scope.settings.holdUntil, 'medium', 'UTC');
                            
                         
                           fixLoadingOff();
                           
                       });
                }
                //*************************************************************************************************
                $scope.getDaySetting = function () {
                    deviceProxy.getDaySetting($scope.deviceId)
                       .success(function (data) {
                           $scope.daySetting = data;
                           $scope.daySettingConnector.CallbackDown(data);
                           $scope.showDirective = true;
                       });
                }
          
                ////*********************************************changeDeviceName(Outer)**************************************************************
                $scope.changeDeviceName = function (id, newName) {
                    deviceProxy.changeDeviceName(id, newName)
                       .success(function (data) {
                           toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                       }).error(function (data, status, headers, config) {
                           toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
                       
                       });
                }

                //********************************************************************************************
                $scope.SaveDeviceAlertsSettings = function (alertForm) {
                    if (alertForm) {
                        $scope.ladda.SaveAlerts = true;     
                        deviceProxy.saveAlertSetting($scope.deviceId, $scope.deviceAlertsSettings)
                            .success(function (data, status, headers, config) {
                                toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                                $scope.ladda.SaveAlerts = false;
                            })
                            .error(function (data, status, headers, config) {
                                toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
                                $scope.ladda.SaveAlerts = false;
                            });
                    } else {
                        toastr.error($filter('translate')('toastrErrForms'), $filter('translate')('Error'));
                    }
                }
                //*******************************************************************************
                $scope.openAddAlerts = function (param) {

                    deviceProxy.openAddAlerts(param)
                    .success(function (data) {
                
                        $scope.alerts = data.body;
                    });
                }
                //*******************************************************************************
                $scope.saveAlertsModal = function () {
                    $scope.ladda.SaveAlertsModal = true;
                    deviceProxy.CtrlAlertsSavings($scope.deviceId, $scope.alerts)
                        .success(function (data, status, headers, config) {
                            toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                            $scope.ladda.SaveAlertsModal = false;
                            $('#deviceAlertSettingsModal').modal('hide');
                         
                        })
                        .error(function (data, status, headers, config) {
                            toastr.error($filter('translate')('toastrErrMsgGet'));
                            $('#deviceAlertSettingsModal').modal('hide');
                        });
                }
               
                ////*******************************************switchDeviceAlerts(Outer)****************************************************************
                $scope.switchDeviceAlerts = function (isAlert) {
                    if ($scope.privilige) {
                        $scope.deviceAlertsSettings.isAlertsEnabled = !isAlert;
                    }
                };
                ////*******************************************switchUseWeather(Outer)****************************************************************
                $scope.switchUseWeather = function (bool) {
                    if ($scope.privilige) {
                        $scope.settings.userWeatherSavingAlgorithm = !bool;
                    }
                    

                };
                ////*********************************************changeDay(Outer)**************************************************************
                $scope.changeDay = function (dayNum, dayString) {
                    $scope.currentDayNum = dayNum;
                    $scope.currentDayString = dayString;

                }
                ////********************************************saveSchedual(Outer)***************************************************************         
                $scope.saveSchedual = function () {
                    $scope.ladda.scheduleView = true;

                    deviceProxy.SaveSchedule($scope.deviceId, $scope.irrigationSchedule)
                       .success(function (data) {
                           toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                           $scope.ladda.scheduleView = false;
                       }).error(function (data, status, headers, config) {
                           toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));

                       });
                   
                    
                }
                ////*********************************************SaveSettings(Outer)**************************************************************
                $scope.SaveSettings = function () {
                    $scope.ladda.settings = true;
                    var obj = {
                        'deviceSettings': $scope.settings,
                        'displaySettings': $scope.displaySettings,
                    }
                    deviceProxy.SaveSettings($scope.deviceId, obj)
                        .success(function (data) {
                            toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                            $scope.ladda.settings = false;
                        }).error(function (data, status, headers, config) {
                            toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));

                        });
                }
                ////*******************************************switchDeviceAlerts(Outer)****************************************************************
                $scope.switchUseSeason = function (isSeason) {
                    if ($scope.privilige) {
                        $scope.settings.useSiteSessionSettings = !isSeason;
                    }
                };
                ////*********************************************SaveIrrigatingSettings(Outer)**************************************************************
                $scope.SaveIrrigatingSettings = function (irrigationForm) {
                    if (irrigationForm) {
                        $scope.ladda.irrigatingSettings = true;
                        var obj = {
                            'irrigatingSettings': $scope.irrigatingSettings
                        }
                        deviceProxy.SaveSettings($scope.deviceId, obj)
                            .success(function (data) {
                                toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                                $scope.ladda.irrigatingSettings = false;
                            }).error(function (data, status, headers, config) {
                                toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));

                            });
                    } else {
                        toastr.error($filter('translate')('toastrErrForms'), $filter('translate')('Error'));
                    }
                }
                ////************************************************SaveRainSensor(Outer)***********************************************************
                $scope.SaveRainSensor = function (RainForm) {
                    if (RainForm) {
                        $scope.ladda.rainSensorSettings = true;
                        var obj = {
                            'rainSensorSettings': $scope.rainSensorSettings
                        }
                        deviceProxy.SaveSettings($scope.deviceId, obj)
                            .success(function (data) {
                                toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                                $scope.ladda.rainSensorSettings = false;
                            }).error(function (data, status, headers, config) {
                                toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));

                            });
                    } else {
                        toastr.error($filter('translate')('toastrErrForms'), $filter('translate')('Error'));
                    }
                }
                ////************************************************SaveflowSensorSettings(Outer)***********************************************************
                $scope.SaveflowSensorSettings = function (FlowForm) {
                    if (FlowForm){
                    $scope.ladda.flowSensorSettings = true;
                    var obj = {
                        'flowSensorSettings': $scope.flowSensorSettings
                    }
                    deviceProxy.SaveSettings($scope.deviceId, obj)
                        .success(function (data) {
                            toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                            $scope.ladda.flowSensorSettings = false;
                        }).error(function (data, status, headers, config) {
                            toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));

                        });
                    } else {
                        toastr.error($filter('translate')('toastrErrForms'), $filter('translate')('Error'));
                    }
                }
                ////************************************************getZone(Outer)***********************************************************
                $scope.getZone = function (zoneId, zoneName) {
                    //zone irrigation sceduale
                    $scope.currentZoneName = zoneName;
                    $scope.zoneId = zoneId;
                    zoneProxy.getZoneSchedule($scope.deviceId, zoneId)
                       .success(function (data) {
                           $scope.zoneScheduleView = data.body.scheduleView;
                       }).error(function (data, status, headers, config) {
                           toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));

                       });
                }
                //************************************************saveIrrigationByzoneSchedule(Outer)****************************
                $scope.saveIrrigationByzoneSchedule = function () {
                    //zone irrigation sceduale
                    zoneProxy.saveTableIrrigationByZone($scope.deviceId, $scope.zoneId, $scope.zoneScheduleView)
                            .success(function (data) {
                                toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                            }).error(function (data, status, headers, config) {
                                toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));

                            });
                }
                //*************************************************NextZone(Outer)***************************
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
                //***************************************************PrevZone(Outer)*************************
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
                //************************************************deleteCtrl(Outer)****************************
                $scope.deleteCtrl = function (ControllerId) {
                    $scope.ladda.deleteCtrl = true;
                    deviceProxy.deleteCtrl(ControllerId)
                    .success(function (data, status, headers, config) {
                        toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                        $scope.ladda.deleteCtrl = false;
                        $state.go('site.preview.list', { projectId: $scope.projectId, siteId: $scope.siteId });
                    })
                    .error(function (data, status, headers, config) {
                        toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
                    });
                }
                //****************************************************************************
                mainRouter.register("saveScedual", function (data) {
                    $scope.irrigationSchedule = data;
                });
                //****************************************************************
                $scope.daySettingConnector.SetCallbackUp(function (data) {

                    $('#daySetting').modal('hide');

                });
               //*************************************************Link***************************
            }],
            link: function (scope, element, attrs, ngModel) {
                if (!ngModel) return; // do nothing if no ng-model
                ngModel.$render = function () {
                    scope.deviceId = ngModel.$viewValue;
                    scope.getViewPage(scope.deviceId);
                };
            }
        };
    }

})(angular);


