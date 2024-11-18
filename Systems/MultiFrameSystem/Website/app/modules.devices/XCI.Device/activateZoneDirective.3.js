
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.device')
        .directive('activateZones', activateZonesFactory);
    /*********************************************************************************************************************************************************************/
    function activateZonesFactory() {
        return {
            restrict: 'EA',
            require: '?ngModel',
            templateUrl: 'app/modules.devices/XCI.Device/activateZones.html',
            controller: ['$scope', '$window', 'baseProxy', 'deviceProxy', 'zoneProxy', '$state', 'mainRouter', '$filter', function ($scope, $window, baseProxy, deviceProxy, zoneProxy, $state, mainRouter, $filter) {
              
                $scope.getZonesActivateList = function (deviceId) {
             
                    deviceProxy.getZonesActivateList(deviceId)
                        .success(function (data, status, headers, config) {
                            $scope.zonesList = data.body;
                        }).error(function (data, status, headers, config) {
                      
                        });
                }
          
                //************************************************************
                $scope.switch = function (isOne) {
                   
                    isOne.tb.isEnabled = !isOne.tb.isEnabled;
                    deviceProxy.activateZone($scope.deviceId, isOne.tb)
                    .success(function (data, status, headers, config) {
                        mainRouter.callkey("refreshTable", {});
                        toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                    }).error(function (data, status, headers, config) {
                        toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
                    });
                }
                //**************************************************************
                $scope.goToZone = function (zoneId) {
                    $state.go('device.XCI_device.zones.adviser', { zoneId: zoneId });
                }

                //***************************************************************
            }
           
            ],
            link: function (scope, element, attr, ngModel) {

                if (!ngModel) return; // do nothing if no ng-model
                ngModel.$render = function () {
                    scope.deviceId = ngModel.$viewValue;
                    scope.getZonesActivateList(ngModel.$viewValue)
                };
               

            }
       
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);






