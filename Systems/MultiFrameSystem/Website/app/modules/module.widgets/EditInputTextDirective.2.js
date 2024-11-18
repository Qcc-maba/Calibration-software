(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('editInputText', editInputTextFactory);
    /*******************************************************************************************************************************************************************/
    function editInputTextFactory($log) {

        return {
            restrict: 'A',
            require: '?ngModel',
            link: function (scope, element, attrs, ngModel) {

                function resize(str) {
                    // var inputText = $(element).val();
                    var dummy = $('<div>').html(str);
                    dummy.css('position', 'absolute');
                    dummy.css('position', 'absolute');
                    dummy.css('font-size', $(element).css('font-size'));
                    dummy.css('width', 'auto');
                    $(body).append(dummy)
                    var width = dummy.width() + 10;
                    if (width<210){
                            $(element).attr('style', 'width:' + width + 'px!important');
                            $(element).val(str);
                    }
                    dummy.remove()
                }

                if (!ngModel) return;
                ngModel.$render = function () {

                    var name = ngModel.$viewValue;
                    resize(name);
                };
                var x = 0;
                var clickCallBack = attrs.editInputText;
                var btn = null;
                var originalValue;



                element.focusin(function () {
                    if (!btn) {
                        originalValue = element.val();
                        var str = "<input type='button' class='editGo' value='GO'/>";
                        btn = $(str).insertAfter(element);

                        btn.on("click", function () {
                            scope.$eval(clickCallBack);
                            originalValue = element.val();
                            btn.hide();

                        });
                    }

                    btn.show();
                });
                element.focusout(function (event) {


                    window.setTimeout(function () {
                        btn.fadeOut(500);
                        element.val(originalValue);
                        resize(originalValue)
                    }, 200);


                });

                $(element).bind("keydown keyup", function () {
                    resize(element.val());
                });



            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);