(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('selectOnClick', selectOnClickFactory);
    /*******************************************************************************************************************************************************************/
    function selectOnClickFactory($log) {

        return {
            restrict: 'A',
            link: function (scope, element, attrs) {
                element.on('click', function () {
                    this.select();
                });
            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);