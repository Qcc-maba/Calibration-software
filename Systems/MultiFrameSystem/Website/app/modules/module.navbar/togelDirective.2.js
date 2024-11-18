(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.menuNavigation')
        .directive('togelDirective', togelDirectiveFactory);
    function togelDirectiveFactory() {
        var runToDoAction = function () {
            if ($(this).parents('.navbar-collapse')) {
                $(this).parents('.navbar-collapse').collapse('hide');
                var bool = $('#body').css('overflow-y');
                if (bool == 'hidden') {
                    $('#body').css({ 'overflow-y': 'auto' });
                } else {
                    $('#body').css({ 'overflow-y': 'hidden' });
                }
                
            }
           
        };
       

        return {
            restrict: 'A',

            link: function (scope, element, attrs) {
                runToDoAction();
             
                element.bind('click', runToDoAction);
            }
        };
    }
})(angular);






