
(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.translate')
        .provider('timer', timer);


    //////////////// JavaScript //////////////

    function timer() {

        var _oldTime;
        var SecTimer;
      
        function _timeFinish() {

            clearTimeout(SecTimer)
            SecTimer = setTimeout(function () {
                
                window.location = MAIN_LINKS.LOGIN.link + "&returnUrl=" + encodeURIComponent(window.location.href);

            }, 1200000);

        }
        function _firstTimer() {


            SecTimer = setTimeout(function () {
                
                window.location = MAIN_LINKS.LOGIN.link + "&returnUrl=" + encodeURIComponent(window.location.href);

            }, 1200000);

        }



        return {
            $get: function () {


                //interface
                return {
                    oldTime: _oldTime,
                    timeFinish: _timeFinish,
                    firstTimer: _firstTimer




                };
            }
        }
    }
})(angular);





