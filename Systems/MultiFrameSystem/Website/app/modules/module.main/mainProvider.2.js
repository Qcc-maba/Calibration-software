
(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.main')
        .provider('mainProvider', mainProvider);


    //////////////// JavaScript //////////////


    function mainProvider() {


        return {
            $get: function () {
                var _currentSite = {
                    data: {
                       
                    }
                };
                var _currentDevice = {
                    data: {
                       
                    }
                };
                var _currentZone = {
                    data: {

                    }
                }

                var _ExchangeNevigation = {
                    data: {
                        loginExchangeView: "",
                        id: ""
                      
                    }
                }
                
               

                //interface
                return {

                    CurrentSite: _currentSite,
                    CurrentDevice: _currentDevice,
                    CurrentZone: _currentZone,
                    ExchangeNevigation: _ExchangeNevigation
                    
                };
            }
        }
    }
})(angular);