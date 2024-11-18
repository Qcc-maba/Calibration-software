
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.XCI.Device')
        .directive('daySetting', daySettingFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function daySettingFactory() {
        return {
            restrict: 'EA',
            templateUrl: 'app/modules.devices/XCI.Device/view/daySetting.html',
            scope: {
                comm: '='
            },
            controller: ['$scope', '$locale', 'translate', '$filter', 'deviceProxy', 'siteProxy', '$stateParams', 'user', 'mainRouter', function ($scope, $locale, translate, $filter, deviceProxy, siteProxy, $stateParams, user, mainRouter) {
                //*************************************Attributs*************************************
                $scope.locale = $locale;
                $scope.clockType = translate.clockType($locale);
                $scope.ladda = {
                    saveDaySettings:false
                }

                if ($stateParams.deviceId) {
                    $scope.useDevice = true;
                    $scope.deviceId = $stateParams.deviceId;
                } else {
                    $scope.useDevice = false;
                    $scope.siteId = $stateParams.siteId;
                }
                
                $scope.privilige = user.getSharingData().sharingData.roleModify;
               
                $scope.dami = ['', ''];
                //***********************************************************
                $scope.comm.SetCallbackDown(function (data) {
                    $scope.daySetting = data.body;
                    $scope.daySetting = $scope.addTimeStrProperty($scope.daySetting);
                    $scope.start = true;

                });
                //***********************************************************
                $scope.saveDaySetting = function () {
                   
                    $scope.ladda.saveDaySetting = true;
                    //**************************************************
                    for (var i = 1; i < $scope.daySetting.listDays.length; i++) {
                        for (var j = 0; j < $scope.daySetting.listDays[i].times.length; j++) {
                            $scope.daySetting.listDays[i].times[j].time = $scope.daySetting.listDays[0].times[j].time;
                            
                        }

                    }

                    //***************************************************


                    if ($scope.useDevice) {
                        deviceProxy.saveDaySetting($scope.deviceId, $scope.daySetting.listDays)
                          .success(function (data) {
                              $scope.comm.CallbackUp();
                              mainRouter.callkey("refreshTable", {});
                              $scope.ladda.saveDaySetting = false;
                          });
                    } else {
                        siteProxy.saveOneSesson($scope.siteId, $scope.daySetting.sessionID, $scope.daySetting.listDays)
                                     .success(function (data) {

                                         $scope.comm.CallbackUp();
                                         $scope.ladda.saveDaySetting = false;
                                         toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                                     }).error(function (data, status, headers, config) {
                                         toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));

                                     });
                    }
                    
                 
                }
                //**********************************************************
                $scope.addTimeStrProperty = function (daySetting) {
                    for (var i = 0; i < daySetting.listDays.length; i++) {
                        for (var j = 0; j < daySetting.listDays[i].times.length; j++) {
                            var time = $filter('date')(translate.convertUnixToTime(daySetting.listDays[i].times[j].time), 'shortTime');
                            daySetting.listDays[i].times[j]['timeStr'] = time;
                        }
                        
                    }
                    
                    return daySetting;
                }
                //***********************************************************
                $scope.saveLastDateObject = function (obj) {
                    $scope.lastObj = jQuery.extend(true, {}, obj);
                }
                //**********************************************************
                $scope.dateValidateAndPharse = function (obj, index) {
                    if (dateValidate(obj, index, $scope.daySetting.listDays[0].times)) {
                       

                        $scope.daySetting.listDays[0].times.sort(function (a, b) {
                            return a.time - b.time;
                        })
                        } else {
                        toastr.error('Start Date Error');
                            for (var a in $scope.lastObj) {
                                obj[a] = $scope.lastObj[a];
                            }
                           
                        }
                }
                //**************************************************************
                function dateValidate(obj, index, list) {
                    var count = 0;
                        obj.time = translate.stringToUnix(obj.timeStr);
                        for (var i = 0; i < list.length; i++) {
                            if (obj.time == list[i].time) {
                                count++;
                            }
                        }
                        if (count > 1 && obj.time!=0 && obj.time!=86340) {
                            return false;
                        }
                        return true;
                }
                //*************************************************************************************
                //function pharseDate(obj) {
                //        obj.time = obj.timeStr;
                //        obj.timeStr = translate.convertUnixToTime(obj.time);
                //}

            }],
            link: function (scope, element, attrs) {
                scope.attr = attrs.param;    //site or device

            }




        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);






