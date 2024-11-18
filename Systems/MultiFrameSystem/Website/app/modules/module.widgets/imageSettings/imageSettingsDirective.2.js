(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('imageSettings', imageSettingsFactory);
    /*******************************************************************************************************************************************************************/
    function imageSettingsFactory() {

        return {
            restrict: 'EA',
            require: '?ngModel',
            templateUrl: 'app/modules/module.widgets/imageSettings/imageSettings.html',
            link: function (scope, element, attrs, ngModel) {
               

                if (!ngModel) return;
                ngModel.$render = function () {
                    
                        scope.url = ngModel.$viewValue;
                     
                  

                };
            
            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);
