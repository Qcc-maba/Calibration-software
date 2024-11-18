(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('flipclock', flipclockFactory);
    /*******************************************************************************************************************************************************************/
    function flipclockFactory($log) {

        return {
            restrict: 'EA',
            require: '?ngModel',

            link: function (scope, element, attrs, ngModel) {



               

                if (!ngModel) return;
                ngModel.$render = function () {
                 
                    var value = ngModel.$viewValue;
                    $(element).flipcountdown({ size: 'sm', tick: value });

                };

            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);