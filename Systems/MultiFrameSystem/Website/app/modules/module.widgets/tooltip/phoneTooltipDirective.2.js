(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('phoneTooltip', phoneTooltipFactory);
    /**************************************************************************************************************************************************************/
    function phoneTooltipFactory($filter) {



        return {
            restrict: 'EA',
            scope:{

            },

            link: function (scope, element, attrs, ngModel) {
                function detectmob() {
                    //if (navigator.userAgent.match(/Android/i)
                    //|| navigator.userAgent.match(/webOS/i)
                    //|| navigator.userAgent.match(/iPhone/i)
                    //|| navigator.userAgent.match(/iPad/i)
                    //|| navigator.userAgent.match(/iPod/i)
                    //|| navigator.userAgent.match(/BlackBerry/i)
                    //|| navigator.userAgent.match(/Windows Phone/i)
                    //) {
                    //    return true;
                    //}
                    //else {
                    //    return false;
                    //}
                    return true;
                }

                $(element).on({
                    "click": function (e) {

                   
                        if (detectmob()) {
                            var parentElement;
                            attrs.var2 == 'modal' ? parentElement = '.modal-content' : parentElement = '.panel';
                            if (!element.parents(parentElement).prev().hasClass('alert alert-success')) {
                                //scope.str = $filter('translate')(attrs.var1);


                                
                               var div = $("<div>")
                                .addClass('alert alert-success')
                                .insertBefore(element.parents(parentElement));


                               var close = $('<button>x</button>').addClass('close').attr('dataDismiss', 'alert').click(function () { element.parents(parentElement).prev().remove() }).appendTo(div);
                               var icon = $('<i></i>').addClass('clip-question-2').appendTo(div);
                               //var strong = $('<strong>Info</strong>').addClass('colMarginLeft').appendTo(div);
                               var span = $('<span>' + $filter('translate')(attrs.var1) + '</span>').addClass('colMarginLeft').appendTo(div);

                            } else {
                                element.parents(parentElement).prev().remove();
                            }
                           

                        }
                     }
                    });
            
            }
        };
    }
    /*******************************************************************************************************************************************************************************/

})(angular);