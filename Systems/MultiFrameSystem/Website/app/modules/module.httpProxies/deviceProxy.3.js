
(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.httpProxies')
        .provider('deviceProxy', deviceProxy);


    //////////////// JavaScript //////////////

    function deviceProxy() {

       

        return {

            $get: function ($http, baseProxy) {

                var data = baseProxy.Global.data.serverUri + '/Admin/Device';
       
                var xciServices = baseProxy.Global.data.serverXci + '/Device';
                var server_MF_api = baseProxy.Global.data.server_mf;
                var onlineServer = ROOT_ADDR.ONLINE_SERVER + '/online';
                ///////////////////////START DONE///////////////////////////////////////////////////////
                function _openAddAlerts(sn) {

                    return $http.get(xciServices + "/" + sn + "/AlertSettings");
                };
                function _switchDeviceAlerts(sn, isAlertsEnabled) {

                    return $http.post(xciServices + "/" + sn + "/AlertSettings?AlertEnabled=" + isAlertsEnabled);

                };
                function _CtrlAlertsSavings(sn , data1) {
               
                    return $http.post(xciServices + "/" + sn + "/AlertSettings", data1);

                };
                function _deleteCtrl(sn) {

                    return $http.delete(data + "/" + sn + "/Unlink");

                };
                function _SnValidation(sn) {

                    return $http.get(server_MF_api + "/Device/" + sn + "/Verify");

                };
                function _NewCtrlSave(NewCtrlSave) {
    

                    return $http.post(server_MF_api + "/Device/Add", NewCtrlSave);

                };
                function _getZonesList(controllerId) {

                    return $http.get(data + "/" + controllerId + "/Zones");
                };
                function _changeDeviceName(sn, name) {
              

                    return $http.post(data + "/" + sn + "/Name/" + name);

                };
                function _getViewPage(sn) {


                    return $http.get(xciServices + "/" + sn);

                };


                function _getDeviceHoldData(sn) {
                    return $http.get(xciServices + "/" + sn + "/DeviceSettings");
                };

                function _saveDeviceHoldData(sn,obj) {
                    return $http.post(xciServices + "/" + sn + "/DeviceSettings" ,obj );
                };

                function _SaveSettings(sn, data1) {
                    var obj = {};
                    obj.body = data1;

                    return $http.post(xciServices + "/" + sn + "/Settings", obj);

                };
                function _SaveSchedule(sn, data1) {
                    return $http.post(xciServices + "/" + sn + "/Schedule/" + data1.scheduleType, data1);
                };

              
                /////////////////////END DONE///////////////////////////////////////////////////////////
              
                function _getDaySchedule(sn, day) {
                    return $http.get(xciServices + "/" + sn + "/Schedule/Weekly/" + day);

                };

                function _saveDaySchedule(sn, day, data1) {
                    return $http.post(xciServices + "/" + sn + "/Schedule/Weekly/" + day, data1);
                };

                function _changeTableType(sn, type) {
                    return $http.get(xciServices + "/" + sn + "/Schedule/?sType=" + type);
                };

                function _GetCoordinate(add) {
                    return $http.get('https://maps.googleapis.com/maps/api/geocode/json?address=' + add + '&key=' + baseProxy.Global.data.GoogleKey);
                };

                function _getZonesActivateList(sn) {
                    return $http.get(xciServices + "/" + sn + "/Zones");
                    //return $http.get(xciServices + "/" + sn + "/Zones");
                };

                function _activateZone(sn,data1) {
                    return $http.post(xciServices + "/" + sn + "/Zones" , data1);

                };

                function _getDaySetting(sn) {
                    return $http.get(xciServices + "/" + sn + "/DaySetting");

                };
                function _saveDaySetting(sn ,obj) {
                    return $http.post(xciServices + "/" + sn + "/DaySetting",obj);

                };
                function _saveAlertSetting(sn, obj) {
                    return $http.post(xciServices + "/" + sn + "/AlertThresholdSettings", obj);

                };

                //*******************online

                function _getDeviceOnline(sn) {
                    return $http.get(onlineServer + "/device/?deviceId=" + sn);
                };
                function _manualZoneOperationOnline(sn, zoneId,time) {
                    return $http.post(onlineServer + "/device/manualStart/?sn=" + sn+"&zoneId="+zoneId+"&time="+time);
                };
                









                //interface
                return {
                    openAddAlerts: _openAddAlerts,
                    switchDeviceAlerts: _switchDeviceAlerts,
                    CtrlAlertsSavings: _CtrlAlertsSavings,
                    deleteCtrl: _deleteCtrl,
                    SnValidation: _SnValidation,
                    NewCtrlSave: _NewCtrlSave,
                    getZonesList: _getZonesList,
                    changeDeviceName: _changeDeviceName,
                    getViewPage: _getViewPage,
                    SaveSettings: _SaveSettings,
                    getDaySchedule: _getDaySchedule,
                    changeTableType: _changeTableType,
                    SaveSchedule: _SaveSchedule,
                    saveDaySchedule:_saveDaySchedule,
                    GetCoordinate: _GetCoordinate,
                    getZonesActivateList: _getZonesActivateList,
                    activateZone: _activateZone,
                    getDeviceHoldData: _getDeviceHoldData,
                    saveDeviceHoldData: _saveDeviceHoldData,
                    getDaySetting: _getDaySetting,
                    saveDaySetting: _saveDaySetting,
                    saveAlertSetting: _saveAlertSetting,
                    getDeviceOnline: _getDeviceOnline,
                    manualZoneOperationOnline: _manualZoneOperationOnline
                };
            }
        }
    }
})(angular);