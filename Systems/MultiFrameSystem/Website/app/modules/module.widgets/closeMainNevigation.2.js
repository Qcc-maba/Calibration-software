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
                    if ($(e.target).hasClass('title') || $(e.target).hasClass("btn")) {
                        element.removeClass("in");
                        element.attr("aria-expanded", false);
                    } else {
                      
                    }
                })
            }
        }

    }
})(angular);