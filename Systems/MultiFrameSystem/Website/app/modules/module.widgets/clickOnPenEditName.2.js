(function (angular) {
    'use strict';

    angular.module('module.widgets')
      .directive('pen', penFactory);

    /**********************************************************************************************************************************************************************/
    function penFactory() {

        return {
            restrict: 'A',
            link: function (scope, element, attr) {

                element.bind('click', function () {
                    element.parent().parent().children('.Name').focus();
                })
            }
        }

    }
})(angular);