(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.filters')
        .filter('flowFilter', function () {

            return function (param, Type) {
                var newFlow = 0;
                switch (Type) {
                    case 0:
                        newFlow = param / 1000;
                        newFlow = newFlow.toFixed(1);
                        break;
                    case 1:
                        newFlow = param / 1000;
                        newFlow = newFlow.toFixed(2);
                        break;
                    case 2:
                        newFlow = param / 1000;
                        newFlow = newFlow.toFixed(2);
                        break;
                    case 3:
                        newFlow = param / 1000;
                        newFlow = newFlow.toFixed(2);
                        break;
                }

                return newFlow;
            };
        }).filter('secToStr', function () {

            return function (seconds) {
                var hourStr = "00:";
                var minStr='';
                var secStr = '';
                var hour = parseInt((seconds / 3600));
                var rest = seconds % 3600;
                var min = rest / 60;
                var sec = rest % 60;
                if (hour > 0 && hour <= 9) {   //1 digit
                    hourStr = '0' + hour.toString() + ":";
                } else if (hour > 9 ) {
                    hourStr = hour.toString()+":";
                }
                if (min > 9) {  // more than 1 digits
                    minStr = min.toString();
                } else {
                    minStr = '0'+min.toString();
                }
                if (sec > 9) {  // more than 1 digits
                    secStr = sec.toString();
                } else {
                    secStr = '0' + sec.toString();
                }

                return hourStr+minStr + ':' + secStr;
            };
        }).filter('num', function() {
            return function(input) {
                return parseInt(input, 10);
            }
        });
    /*******************************************************************************************************************************************************************************/

})(angular);