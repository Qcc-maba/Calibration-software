/// <reference path="weatherSaving.html" />
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('progress', progressFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function progressFactory($log) {

        return {
            restrict: 'EA',
          
            require: '?ngModel',
          
            controller: function ($scope) {

               
            },
            link: function (scope, element, attrs, ngModel) {
               
                function progress(percent, $element) {
                    var progressBarWidth = percent * $element.width() / 100;
                    $element.find('div').animate({ width: progressBarWidth }, 500).html(percent + "%&nbsp;");
                }

                ngModel.$render = function () {
                    if (ngModel && ngModel.$viewValue) {
                     
                        progress(ngModel.$viewValue, element)
                    }
                };
            }
        };//return
    }

    /*******************************************************************************************************************************************************************************/

})(angular);
