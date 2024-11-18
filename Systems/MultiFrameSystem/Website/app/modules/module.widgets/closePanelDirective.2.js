(function (angular) {
    'use strict';

    angular.module('module.widgets')
      .directive('closePanel', closePanelFactory);

    /**********************************************************************************************************************************************************************/
    function closePanelFactory($log) {

        return {
            restrict: 'A',
            link: function (scope, element, attr) {
                scope.height  = element.parent().parent().parent().children('.panel-body').css("heigth");
                element.bind('click', function () {
                    
                    if( element.parent().parent().parent().children('.panel-body').css("display")=="none" )
                    {
                        element.parent().parent().parent().children('.panel-body').slideDown("fast");
                        element.removeClass('fa-chevron-down');
                        element.addClass('fa-chevron-up');
                    } else {
                        element.parent().parent().parent().children('.panel-body').slideUp("fast");;
                        element.removeClass('fa-chevron-up');
                        element.addClass('fa-chevron-down');
                    }
                })
            }
        }

    }
})(angular);