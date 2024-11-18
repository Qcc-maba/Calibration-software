
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.XCI.Device')
        .directive('ctrlHold', ctrlHoldFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function ctrlHoldFactory($log) {

        return {
            restrict: 'EA',
            templateUrl: 'app/modules.devices/XCI.Device/online/ctrlHold.html',
            controller: ['$scope', '$locale', '$filter', 'translate', 'deviceProxy', function ($scope, $locale, $filter, translate, deviceProxy) {
                $scope.isDeviceOn= true,
                $scope.deviceStatus = {
                    isDeviceOn: true,
                    type: 'Permantly',
                    date: '',
                    time: ''
                };

                $scope.ladda = {
                    "hold": false
                };
               


                //************************************************************
                $scope.getDeviceStatus = function () {
                     deviceProxy.getDeviceHoldData($scope.deviceId)
                        .success(function (data, status, headers, config) {
                            $scope.deviceHoldData = data.body;
                            if (data.body.holdType == null) { // the device is active
                                $scope.isDeviceOn = true;
                                
                            } else {
                                if (data.body.holdType == 0) { // Hold until date
                                    $scope.deviceStatus.type = 'custom';
                                    $scope.isDeviceOn = false;
                                }
                                if (data.body.holdType == 1) { // parmanent Hold
                                    $scope.deviceStatus.type = 'Permantly';
                                    $scope.isDeviceOn = false;

                                }
                                $scope.setDate(translate.FixUnixGmtFromServer(data.body.holdUntil));
                                $scope.setTime(translate.FixUnixGmtFromServer(data.body.holdUntil));
                                
                            }
                            
                            
                        }).error(function (data, status, headers, config) {
                            toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
                        });
                }
                $scope.getDeviceStatus();
                //************************************************************
                $scope.switchBotton = function (data) {
                    $scope.isDeviceOn = !data.isDeviceOn;
                    if (!$scope.isDeviceOn) { // device is off show date
                        $scope.deviceHoldData.holdType = 0;
                        $scope.deviceStatus.type = 'custom';
                        $scope.setDate(translate.FixUnixGmtFromServer($scope.deviceHoldData.holdUntil));
                        $scope.setTime(translate.FixUnixGmtFromServer($scope.deviceHoldData.holdUntil));
                    } else {
                        $scope.deviceHoldData.holdType = null;
                    }
                }
                //**************************************************************


             
              
                $scope.setDate = function (unix) {
                    $scope.deviceStatus.date = $filter('date')(unix, 'mediumDate');
                }
                $scope.setTime = function (unix) {
                    $scope.deviceStatus.time = $filter('date')(unix, 'shortTime');
                }
                $scope.clockType = translate.clockType($locale);
                
                $scope.saveHold = function () {
                    $scope.ladda.hold = true;
                 
                    $scope.deviceHoldData.holdUntil = translate.fullDateStringToUnixServer($scope.deviceStatus.date, $scope.deviceStatus.time);
                    if ($scope.deviceHoldData.holdType != null) {
                        $scope.deviceStatus.type == 'custom' ? $scope.deviceHoldData.holdType = 0 : $scope.deviceHoldData.holdType = 1;
                    }
                    deviceProxy.saveDeviceHoldData($scope.deviceId,$scope.deviceHoldData)
                       .success(function (data, status, headers, config) {
                           $scope.ladda.hold = false;
                           toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                           $('#hold').modal('hide');
                       }).error(function (data, status, headers, config) {
                           toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
                       });

                }

            }],
            link: function (scope, element, attrs) {
                var deviceId = attrs.device;
   
            }

        };//return
    }

    /*******************************************************************************************************************************************************************************/

})(angular);
