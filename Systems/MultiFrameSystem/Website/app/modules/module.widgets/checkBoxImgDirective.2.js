(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('imgCheckbox', imgCheckboxFactory);
    /*******************************************************************************************************************************************************************/
    function imgCheckboxFactory() {

        return {
            restrict: 'EA',
            link: function (scope, element, attrs) {


                check_param(attrs.param);
                attrs.$observe('param', function (val) {
                    check_param(val);
                });

                function check_param(param) {
                    if (param == "false") { //read only
                        $(element).prop('readonly', true);


                    } else {
                        $(element).prop('readonly', false);
                        $(element).css("background-color", "white");
                    }
                }







            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);