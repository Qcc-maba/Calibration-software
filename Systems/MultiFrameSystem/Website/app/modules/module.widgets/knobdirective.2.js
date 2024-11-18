(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('knobDirective', knobDirectiveFactory);
    /*******************************************************************************************************************************************************************/
    function knobDirectiveFactory() {

        return {
            restrict: 'EA',
            require: '?ngModel',

            link: function (scope, element, attrs, ngModel) {

              
               
                if (!ngModel) return; // do nothing if no ng-model
                ngModel.$render = function () {
                    scope.currentValue = ngModel.$viewValue;
                    $(element).val(scope.currentValue)
                    $(element).knob({
                        'min': 0,
                        'max': 100,
                        'readOnly': true,
                        'width': 50,
                        'height': 50,
                        'fgColor': '#5d6178',
                        
                        'draw' : function () { $(this.i).val(this.cv + '%'); }
                    

                    });

                };
              

             
                
            }
        }; 
    }

    /*******************************************************************************************************************************************************************************/

})(angular);
