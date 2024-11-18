(function (angular) {
    'use strict';

    angular.module('module.widgets')
      .directive('addClass', addClassFactory);

    /**********************************************************************************************************************************************************************/
    function addClassFactory() {

        return {
            restrict: 'A',
            link: function (scope, element, attr) {

                element.bind('click', function (e) {
                    if ($(e.target).hasClass('selected')) {
                      
                    } else {
                        $(element).parent().find('*').each(function () {
                            $(this).removeClass('selected');
                        });
                        element.addClass('selected');
                    }
                })
            }
        }

    }
})(angular);