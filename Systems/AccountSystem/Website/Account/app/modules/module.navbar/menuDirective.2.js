(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.menuNavigation')
        .directive('menuDirective', menuDirectiveFactory);
    function menuDirectiveFactory() {





        var runToDoAction = function () {
            if ($(this).parents('.navbar-collapse')) {
                $(this).parents('.navbar-collapse').collapse('hide');;
            }
        };




        

        return {
            restrict: 'A',

            link: function (scope, element, attrs) {
              
                element.bind('click', runToDoAction);
            }
        };
    }
})(angular);






