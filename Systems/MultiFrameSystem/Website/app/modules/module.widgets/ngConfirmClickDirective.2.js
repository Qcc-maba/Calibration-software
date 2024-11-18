
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('ngConfirmClick', ngConfirmClickFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function ngConfirmClickFactory($log) {
        return {
            link: function (scope, element, attr) {
                var msg = attr.ngConfirmClick || "Are you sure?";
                var clickAction = attr.confirmedClick;
                
                element.bind('click', function (event) {
                    var retVal = prompt("Please write \"i want to delete\" : ", " I...");
                    if (window.confirm(msg)) {
                        if (retVal == "i want to delete") {
                            scope.$eval(clickAction)
                        } else {
                            toastr.error('You Wrong... ');
                        }
                        
                    }
                });
            }
        };


       
    }

    /*******************************************************************************************************************************************************************************/

})(angular);






