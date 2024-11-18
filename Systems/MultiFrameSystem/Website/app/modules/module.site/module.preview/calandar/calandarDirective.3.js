
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site.preview')
        .directive('calandar', calandarFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function calandarFactory() {

        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.site/module.preview/calandar/calandar.html',

            controller: ['$scope', '$http', '$filter', '$stateParams', 'siteProxy', 'deviceProxy', function ($scope, $http, $filter, $stateParams, siteProxy, deviceProxy) {

                //************************************************Attributs*******************

                //************************************************functions*******************

                //***********************GetsiteConT(Inner)******************
                function GetsiteConT(param) {
                    siteProxy.GetsiteConT(param)
                       .success(function (data) {

                           $scope.controllers = data;
                           $scope.flag1 = true;
                           fixLoadingOff();
                       }).error(function (data, status, headers, config) {
                           toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
                           fixLoadingOff();
                       });
                }

                $scope.choosenDevice = function (sn) {

                    siteProxy.GetDeviceInfo(sn)
                        .success(function (data) {
                            $scope.currentDevice = data.body;


                        }).error(function (data, status, headers, config) {
                            toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
                        });
                }




                GetsiteConT($stateParams.siteId);

            }
            ]
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);






