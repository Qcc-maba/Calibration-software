(function (angular) {
    'use strict';

    angular.module('module.widgets')
      .directive('closeModel', closeModelFactory);

    /*********************************************************************Weather****************************************************************************************************/
    function closeModelFactory($log) {

        return {
            restrict: 'A',
            link: function (scope, element, attr) {
            
                //scope.getZone = function (zoneId, zoneName) {
                //    alert('hhh');
                //}
                scope.dismiss = function () {
                    element.modal('hide');

                   // scope.getZone(1, 1);
                };
            }
        }

    }
})(angular);