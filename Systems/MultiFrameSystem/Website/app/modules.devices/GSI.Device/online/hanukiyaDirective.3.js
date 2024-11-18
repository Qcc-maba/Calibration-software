
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.GSI.Device')
        .directive('hanukiya', ['$filter', hanukiyaDFactory]);
    /***********************************************************************************************************************************************************************/
    function hanukiyaDFactory($filter) {
        return {
            restrict: 'EA',
            templateUrl: 'app/modules.devices/GSI.Device/online/hanukiya.html',

            controller: ['$scope', '$rootScope', 'siteProxy', '$filter', '$state',
                function ($scope, $rootScope, siteProxy, $filter, $state) {
                    


                }],
            link: function (scope, element, attrs, ngModel) {

                

            }

        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);






