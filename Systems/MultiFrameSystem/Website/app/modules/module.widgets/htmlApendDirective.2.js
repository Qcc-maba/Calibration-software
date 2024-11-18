(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('htmlApend', htmlApendFactory);
    /*********************************************************************************************************************************************************************/
    function htmlApendFactory($log) {

        return {
            restrict: 'A',

            link: function (scope, element, attrs) {
              
                var htmlString = attrs.htmlApend;
       
                $(htmlString).appendTo(element);
               
            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);