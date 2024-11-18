
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('dropeDown', dropeDownFactory);
    /**************************************************************************************************************************************************************/
    function dropeDownFactory($filter) {



        return {
            restrict: 'EA',
       

            link: function (scope, element, attrs, ngModel) {

               
                $(element).on({
                    "click": function (e) {
                        var target = $(e.target);
                        if (target.parents('.dropDownSearch').length >=1) {
                            e.stopPropagation();
                        }
                        
                    }
                });
            }
        };
    }
    /*******************************************************************************************************************************************************************************/

})(angular);







