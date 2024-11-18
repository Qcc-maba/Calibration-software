(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('timePicker2', timeDirectiveFactory);
    function timeDirectiveFactory() {

        return {
            restrict: 'EA',
            link: function (scope, element, attr) {
                var twelvehour = false;
                if (attr.param == "AMPM") {
                    twelvehour = true;
                }
                $(element).clockpicker({
                    autoclose: true,
                    twelvehour: twelvehour
                });
                element.bind("click", function () {
                    $(element).clockpicker('show');
                })

            }

        };//return
    }

})(angular);


