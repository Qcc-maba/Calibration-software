
(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.httpProxies')
        .provider('weatherProxy', weatherProxy);


    //////////////// JavaScript //////////////

    function weatherProxy() {



        return {

            $get: function ($http, baseProxy) {


               // var data = baseProxy.Global.data.serverMF + '/Weather';
                var data = baseProxy.Global.data.serverMF + '/Weather'
                var server_MF_api = baseProxy.Global.data.server_mf;

                ///////////////////////START DONE///////////////////////////////////////////////////////
                function _GetWeatherDetails(id, time,param) {

                   
                    if (param) {
                        return $http.get(server_MF_api + "/Weather/Device/" + id + "/WeeklyForecast?dateTicks=" + time);
                    } else {
                        //return $http.get(data + "/" + id + "/Forecast?dateTicks=" + time);
                        return $http.get(server_MF_api + "/Weather/" + id + "/WeeklyForecast?dateTicks=" + time);
                    }
                        
                };
                function _GetWeatherSettings(siteId) {

                    return $http.get(server_MF_api + "/Weather/" + siteId + "/Setting");

                };
                function _SaveWeatherSettings(siteId, Data1, applyHierarchy) {
               
                    //return $http.post(data + "/" + siteId + "/Setting?isSubSetting=" + applyHierarchy, Data1);
                    return $http.post(server_MF_api + "/Weather/" + siteId + "/Setting?AsDefaultValuesOnly=" + applyHierarchy, Data1);
                };
                









                //interface
                return {

                    GetWeatherDetails: _GetWeatherDetails,
                    GetWeatherSettings:_GetWeatherSettings,
                    SaveWeatherSettings: _SaveWeatherSettings
                   
                };
            }
        }
    }
})(angular);