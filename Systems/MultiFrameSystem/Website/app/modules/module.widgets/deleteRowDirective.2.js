(function (angular) {
    'use strict';

    angular.module('module.widgets')
      .directive('deleteRow', deleteRowFactory);

    /*********************************************************************Weather****************************************************************************************************/
    function deleteRowFactory($log) {

        return {
            restrict: 'A',
            link: function (scope, element, attrs, ngModel) {
              
            
                element.bind('click', function (event) {

                    if (element.parent().parent().find('.line').length != 0) {
                        element.parent().parent().find('.line').remove();
                    }
                    else {
                        var width = element.parent().parent().width() - 100;


                        var line = $('<div>')
                       .appendTo(element.parent().parent())
                       .addClass('line')

                       .width(width);
                    }
                   

                    $(window).resize(function () {
                        var width = element.parent().parent().width() - 100;
                        element.parent().parent().find('.line').width(width);
                    });
                   
                  












                    //var _html = "<div style=\"border-bottom: 3px solid black\">DELETED<div>";
                    //var hr = $(_html).insertBefore(element.parent());
                });
               
            }
        };

    }
})(angular);