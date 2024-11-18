
(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.httpProxies')
        .provider('zoneProxy', zoneProxy);


    //////////////// JavaScript //////////////

    function zoneProxy() {



        return {

            $get: function ($http, baseProxy) {

                var data = baseProxy.Global.data.serverUri + '/Device';
                var xciServices = baseProxy.Global.data.serverXci + '/Zone';

                ///////////////////////START DONE///////////////////////////////////////////////////////
                //function _updateZoneWireColor(controllerId, zoneId, value) {

                //    return $http.post(data + "/" + controllerId + "/Zones/" + zoneId + "?WireColor=" + value);
                //};
                function _updateZoneIsEnabled(controllerId, zoneId, value) {

                    return $http.post(data + "/" + controllerId + "/Zones/" + zoneId + "?IsEnabled=" + value);
                };
                function _updateZoneWeatherSavingAlgorithm(controllerId, zoneId, value) {

                    return $http.post(data + "/" + controllerId + "/Zones/" + zoneId + "?WeatherSavingAlgorithm=" + value);
                };
                function _updateZoneIrrigationFactor(controllerId, zoneId, value) {

                    return $http.post(data + "/" + controllerId + "/Zones/" + zoneId + "?IrrigationFactor=" + value);
                };
                function _getZoneDetails(sn, zoneId) {

                  
                    return $http.get(xciServices + "/" + sn + "/" + zoneId);
                };
                function _getZoneSchedule(sn, zoneId) {

                    return $http.get(xciServices + "/" + sn + "/" + zoneId + "/Schedule?sType=Weekly");
                   
                };
                function _getZoneSaggestionWizard(sn, zoneId) {

                    return $http.get(xciServices + "/" + sn + "/" + zoneId + "/ScheduleAdvisor");
                };
                function _saveSettings(controllerId, zoneId, settings) {
                 
                    return $http.post(xciServices + "/" + controllerId + "/" + zoneId + "/Settings", settings);
                };
                function _flowSensorSettings(controllerId, zoneId, flowSensorSettings) {
                  
                    return $http.post(xciServices + "/" + controllerId + "/" + zoneId + "/FlowSensorSettings", flowSensorSettings);
                };
                function _saveAndGetRecommendation(sn, zoneId , obj) {

                    return $http.post(xciServices + "/" + sn + "/" + zoneId + "/ScheduleAdvisor" , obj);
                };
                function _saveSuggestions(controllerId, zoneId, current) {
                    var obj = {
                        body: {
                            types: current
                        }
                    };
                    
                    return $http.post(data + "/" + controllerId + "/Zones/" + zoneId + "/ScheduleAdvisor", obj);
                };
                function _manualStartIrrigation(controllerId, zoneId, resetTime) {

                    var obj = {
                        body: {
                            time: resetTime
                        }
                    };
                    
                    return $http.post(data + "/" + controllerId + "/Zones/" + zoneId + "/manualStartIrrigation", obj);
                };
                function _saveTableIrrigationByZone(sn, zoneId,type, IrrigationByZone) {
             
                    return $http.post(xciServices + "/" + sn + "/" + zoneId + "/Schedule/" + type, IrrigationByZone);
                };

                function _getIrrigationSuggestion(sn, zoneId) {

                    return $http.get(xciServices + "/" + sn + "/" + zoneId + "/IrrigationSuggestion");

                };
                function _getZoneInfo(sn, zoneId) {

                    return $http.get(xciServices + "/" + sn + "/" + zoneId + "/ZoneInfo");

                };
                function _acceptSuggestions(sn, zoneId) {
                    return $http.post(xciServices + "/" + sn + "/" + zoneId + "/AcceptSuggestion");
                };
                function _changeZoneName(sn,zoneId, name) {
                    return $http.post(xciServices + "/" + sn + "/" + zoneId + "?Name="+name);
                };







                //interface
                return {
                   // updateZoneWireColor: _updateZoneWireColor, //not in use
                    updateZoneIsEnabled: _updateZoneIsEnabled,//not in use
                    updateZoneIrrigationFactor: _updateZoneIrrigationFactor,//not in use
                    updateZoneWeatherSavingAlgorithm: _updateZoneWeatherSavingAlgorithm,//not in use
                    getZoneDetails: _getZoneDetails,
                    getZoneSchedule:_getZoneSchedule,
                    saveSettings: _saveSettings,
                    flowSensorSettings:_flowSensorSettings,
                    getZoneSaggestionWizard: _getZoneSaggestionWizard,
                    acceptSuggestions: _acceptSuggestions,
                    saveAndGetRecommendation: _saveAndGetRecommendation,
                    manualStartIrrigation: _manualStartIrrigation,//not in use
                    saveTableIrrigationByZone: _saveTableIrrigationByZone,
                    getIrrigationSuggestion: _getIrrigationSuggestion,
                    getZoneInfo: _getZoneInfo,
                    changeZoneName: _changeZoneName








                };
            }
        }
    }
})(angular);