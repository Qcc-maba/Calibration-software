
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.GSI.Device')
        .directive('gsiOnline', ['$filter', gsiOnlineDFactory]);
    /***********************************************************************************************************************************************************************/
    function gsiOnlineDFactory($filter) {
        return {
            restrict: 'EA',
            require: '?ngModel',
            templateUrl: 'app/modules.devices/GSI.Device/online/GSI_Online.html',

            controller: ['$scope', '$rootScope', 'siteProxy', '$filter', '$state',
                function ($scope, $rootScope, siteProxy, $filter, $state) {
                    $scope.goToSquare = function () {
                        $state.go('site.preview.squares');
                    }


                }],
            link: function (scope, element, attrs, ngModel) {

                if (!ngModel) return;
                ngModel.$render = function () {

                    scope.deviceId = ngModel.$viewValue;
                    

                };

            }

        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);






