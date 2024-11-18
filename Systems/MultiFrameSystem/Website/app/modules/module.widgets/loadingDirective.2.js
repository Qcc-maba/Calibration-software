(function (angular) {
    'use strict';

    angular.module('module.widgets')
      .directive('loadingDirective', loadingDirectiveFactory);

/*********************************************************************Weather****************************************************************************************************/
function loadingDirectiveFactory($log) {

    return {
        restrict: 'A',
        require: '?ngModel',
        link: function (scope, element, attrs, ngModel) {

            var _html = "<img style=\"width:50px;height:50px\" src=\"content/img/loaders/loading11.gif\">";
            var spinnerElement = $(_html).insertAfter(element);

            function setSpinnerState() {
                if (ngModel.$viewValue) {
                    element.attr("disabled", "disabled");
                    spinnerElement.show();
                }
                else {
                    spinnerElement.hide();
                    element.removeAttr("disabled");
                }
            }

            ngModel.$render = function () {

                setSpinnerState();
            };

            setSpinnerState();
        }
    };

}
})(angular);