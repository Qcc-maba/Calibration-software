(function (angular) {
    'use strict';

    angular.module('module.widgets')
      .directive('allMessages', allMessagesFactory);

    /**********************************************************************************************************************************************************************/
    function allMessagesFactory() {

        return {
            restrict: 'A',
            templateUrl: 'app/modules/module.message/allMessages.html',
            link: function (scope, element, attr) {

              
                element.bind('blur', function () {
                    if ($('#page-sidebar').css("right") == "-500px") {
                        $('#page-sidebar').css("right", "0px");
                        //element.removeClass('open');
                    }
                });
                
               
               
            }
        }

    }
})(angular);