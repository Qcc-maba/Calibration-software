
(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.httpProxies')
        .provider('baseProxy', baseProxy);


    //////////////// JavaScript //////////////

    function baseProxy() {

        var translateProvider;

        var _global = {
            data: {


                serverUri: ROOT_ADDR.SYSTEM_ACCOUNT_API,
             // serverUri: "http://10.0.0.108/WebServices/api",
             // serverUri: "http://bs.eitanr.com:10600/WebServices/api",   

                GoogleKey: "AIzaSyCKESGfcYKGe4QLnn4DESThvwE7xDEObnA"
            }
        };
        function buildPinLocation(lat, lan) {
            while(lan < -180) {
                lan=lan+360
            }
            while (lan > 180) {
                lan = lan - 360
            }
            return {
                latitude: lat,
                longitude: lan
            };
        }
       
        function timeConverter(UNIX_timestamp) {
            var a = new Date(UNIX_timestamp).toLocaleDateString();
          
            return a;
        }
        
       




        function buildLocation(lat, lan) {
            return {

                MapCenter: buildPinLocation(lat, lan),
                zoomLevel: 8,
                mode: "roadMap",
                autoBounds: true
            }

        };

        function saveManualMap(lat, lan, zoomLevel, mode, autoBounds) {
            return {

                MapCenter: buildPinLocation(lat, lan),
                zoomLevel: zoomLevel,
                mode: mode,
                autoBounds: autoBounds
            }

        };



        function convertToStringTime(time) {
            var hours = String(Math.floor(time / 3600));
            var min = String(Math.floor((time % 3600) / 60));
            if (hours.length == 1)
                hours = "0" + hours;
            if (min.length == 1)
                min = "0" + min;

            return hours + ":" + min;

        }

        function convertFromStringTime(time) {
            var d = new Date("1/1/2000 " + time);
          

            return d.getMinutes() * 60 + d.getHours() * 3600;

        }
        return {
            $get: function ($http ) {


                //interface
                return {
                    Global: _global,
                    buildPinLocation: buildPinLocation,
                    buildLocation: buildLocation,
                    saveManualMap: saveManualMap,
                    timeConverter: timeConverter,
                    convertToStringTime: convertToStringTime,
                    convertFromStringTime: convertFromStringTime

                };
            }
        }
    }
})(angular);





