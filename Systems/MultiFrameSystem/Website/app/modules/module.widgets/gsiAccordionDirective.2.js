(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('gsiAccordion', gsiAccordionFactory);
    function gsiAccordionFactory() {

        var changeState = function () {
            if ($(this).children('.fa-chevron-circle-up').length == 1) {
                var i = $(this).children('.fa-chevron-circle-up');
                i.removeClass("fa-chevron-circle-up");
                i.addClass("fa-chevron-circle-down");
                var body = $(this).parents().parents().children('.gsi-panel-body');
                body.css({ 'display': 'none' });

            }
            else{
                var i = $(this).children('.fa-chevron-circle-down');
                i.removeClass("fa-chevron-circle-down");
                i.addClass("fa-chevron-circle-up");
                var body = $(this).parents().parents().children('.gsi-panel-body');
                body.css({ 'display': 'block' });
            }
                
                
 

        };


        return {
            restrict: 'A',

            link: function (scope, element, attrs) {
               

                element.bind('click', changeState);
                
            }
        };
    }
})(angular);