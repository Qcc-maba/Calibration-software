
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site.preview')
        .directive('squares', squaresFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function squaresFactory() {

        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.site/module.preview/squares/squares.html',

            controller: ['$scope', '$http', '$filter', '$stateParams', 'siteProxy', 'deviceProxy', '$state', function ($scope, $http, $filter, $stateParams, siteProxy, deviceProxy, $state) {

                //************************************************Attributs*******************

                //***********************GetsiteConT(Inner)***********************************
                function GetsiteConT(param) {
                    siteProxy.GetsiteConT(param)
                       .success(function (data) {

                           $scope.controllers = data.body;
                           fixLoadingOff();

                       }).error(function (data, status, headers, config) {
                           toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
                           fixLoadingOff();
                       });
                }
                /******************************************************************************/
                function switchType(type, sn, param) {
                    mainProvider.ExchangeNevigation.data.type = "type";
                    switch (type) {
                      
                        case "GSI":
                            if (param == null) {
                                $state.go('site.preview.gsiOnline');
                            } else {
                                $state.go('device.GSI_device.status', { deviceId: sn});
                            }
                            
                            break;
                        case "GSI-AG":
                            if (param == null) {
                                $state.go('site.preview.gsiOnline');
                            } else {
                                $state.go('device.GSI_device.status', { deviceId: sn});
                            }
                            break;
                        case "XCI-WIFI":
                            if (param == null) {
                                $state.go('device.XCI_device.online', { deviceId: sn});
                            } else {
                                $state.go('device.XCI_device.online', { deviceId: sn});
                            }
                            break;
                        case "XCI":
                            if (param == null) {
                                $state.go('device.XCI_device.online', { deviceId: sn});
                            } else {
                                $state.go('device.XCI_device.online', { deviceId: sn});
                            }
                            break;
                    }
                }
                /*****************************************************************/
                $scope.goToOnlineView = function (device) {
                   // fixLoadingOn("goToDevice", device.sn);
                    switchType(device.deviceType, device.sn,'inDevice');

                }
                //*****************************************************************
                
                $scope.goToShortOnline = function (device) {
                    
                    switchType(device.deviceType,device.sn ,null);

                }
              


                /****************************************************************/
                GetsiteConT($stateParams.siteId);

            }
            ]
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);






