
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


                serverUri: ROOT_ADDR.SYSTEM_MF_API,
                serverMF:  ROOT_ADDR.MF_API,
                server_mf: ROOT_ADDR.MF_API_SERVER,
                serverXci: ROOT_ADDR.XCI_API_SERVER,
                GoogleKey: "AIzaSyC4GOEIPbjen7-vzEPh4CbOGQCgl-_oyKE"
            }
        };
        function getObjArrayOfProperty(obj) {
            var arr = [];
            var i = 0;
            for (var property in obj) {
                arr[i] = property;
                i++;
            }
            return arr;
        }
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
        
        function buildLocalizedURI(uri, method, data) {
            var req = {
                method: method || 'GET',
                url: uri,
                headers: {
                    'Accept-Language': translateProvider.Settings.locale + ',en;q=0.8'
                },
                data: data

            }

            return req;
        }




        function buildLocation(lat, lan) {
            return {

                MapCenter: buildPinLocation(lat, lan),
                zoomLevel: 12,
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
            $get: function ($http, translate) {

                translateProvider = translate;

                //interface
                return {
                    Global: _global,
                    buildPinLocation: buildPinLocation,
                    buildLocation: buildLocation,
                    saveManualMap: saveManualMap,
                    buildLocalizedURI: buildLocalizedURI,
                    timeConverter: timeConverter,
                    convertToStringTime: convertToStringTime,
                    convertFromStringTime: convertFromStringTime,
                    getObjArrayOfProperty: getObjArrayOfProperty

                };
            }
        }
    }
})(angular);





