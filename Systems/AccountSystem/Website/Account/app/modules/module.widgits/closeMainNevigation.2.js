(function (angular) {
    'use strict';

    angular.module('module.widgets')
      .directive('closeMainNevigation', closeMainNevigationFactory);

    /**********************************************************************************************************************************************************************/
    function closeMainNevigationFactory($log) {

        return {
            restrict: 'A',
            link: function (scope, element, attr) {

                element.bind('click', function (e) {
                    if ($(e.target).parents('.navbar-collapse').length) {
                        element.removeClass("in");
                        element.attr("aria-expanded", false);
                    }
                })
            }
        }

    }
})(angular);