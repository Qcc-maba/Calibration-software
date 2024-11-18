
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site')
        .directive('leftMessages', leftMessagesFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function leftMessagesFactory() {

        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.site/leftMessages.html',

            controller: ['$scope', '$http', '$filter', '$stateParams', 'siteProxy', 'deviceProxy', function ($scope, $http, $filter, $stateParams, siteProxy, deviceProxy) {

               
            }
            ]
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);






