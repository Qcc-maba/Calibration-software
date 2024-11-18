
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site')
        .directive('wifi', wifiFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function wifiFactory() {

        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.site/wifi.html',

            controller: ['$scope', function ($scope) {

            }
            ]
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);

