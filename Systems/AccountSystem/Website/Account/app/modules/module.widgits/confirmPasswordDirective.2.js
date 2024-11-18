(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('compareTo', compareToFactory);
    /********************************************************************************************************************************************************************/
    function compareToFactory($log) {

        return {
            require: "ngModel",
            scope: {
                otherModelValue: "=compareTo"
            },
            link: function (scope, element, attributes, ngModel) {

                ngModel.$validators.compareTo = function (modelValue) { //will run if someting change on confirm textfild
                    return modelValue == scope.otherModelValue; 
                };

                scope.$watch("otherModelValue", function () {
                    ngModel.$validate(); // run  ngModel.$validators.compareTo if somting change on password
                });
            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);









