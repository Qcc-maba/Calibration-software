(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('datePickerDirective', datePickerDirectiveFactory);
    function datePickerDirectiveFactory($log) {

        return {
            restrict: 'EA',
            scope: {
                callback: '&',
                row: '=myrow',
                type: '=mytype'
            },

            link: function (scope, element, attr) {
                scope.callback = scope.callback();
                element.datepicker({
                    dateFormat: '@',
                  
                    onSelect: function (dateText) {
                   
                            if (scope.type) {
                                scope.callback(scope.row, scope.type, $(this), dateText);
                            }
                            
                        
                    }

                });
            }


        };//return
    }
})(angular);









