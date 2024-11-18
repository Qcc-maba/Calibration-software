
(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.httpProxies')
        .provider('siteProxy', siteProxy);


    //////////////// JavaScript //////////////

    function siteProxy() {

      

        return {

            $get: function ($http, baseProxy) {

               //var data1 = baseProxy.Global.data.serverUri + '/Admin/Site';
               var data = baseProxy.Global.data.serverMF + '/Admin/Site'
               var dataDevice = baseProxy.Global.data.serverMF + '/Admin/Device'
               var server_MF_api = baseProxy.Global.data.server_mf;
               var onlineServer = ROOT_ADDR.ONLINE_SERVER+'/online';
                ///////////////////////START DONE///////////////////////////////////////////////////////
                function _GetControllersLocation(siteId) {
                    //return $http.get(data + "/" + siteId + "/Map");
                    return $http.get(server_MF_api + "/Site/" + siteId + "/Map");
                };
                function _SaveSiteLocation(s, z, Lat, Lan, typeMap, fitBounds) {
                    //return $http.post(data + '/' + s + '/Location', baseProxy.saveManualMap(Lat, Lan, z, typeMap, fitBounds));
                    return $http.post(server_MF_api + '/Site/' + s + '/Location', baseProxy.saveManualMap(Lat, Lan, z, typeMap, fitBounds));
                  
                };

                function _SaveSiteDeviceChangeLocation(siteId, sn, deviceLat, deviceLan) {
                 //return $http.post(data + "/" + siteId + "/Map/Devices/" + sn, baseProxy.buildPinLocation(deviceLat, deviceLan));
                    return $http.post(server_MF_api + "/Site/" + siteId + "/Map/" + sn, baseProxy.buildPinLocation(deviceLat, deviceLan));
                };
                function _GetsiteConT(siteId) {
                    //return $http.get(data + "/" + siteId + "/Devices/");
                    return $http.get(server_MF_api + "/Site/" + siteId + "/Devices/");
                };
                function _CreateNewSite(p, s) {

                   // return $http.post(data + '/?SiteName=' + s + '&ParentProjectID=' + p);
                    return $http.post(server_MF_api + '/Site/?SiteName=' + s + '&ParentProjectID=' + p);
                   
                };
                function _switchDeviceAlerts(sn, isAlertsEnabled) {

                    return $http.post(dataDevice + "/" + sn + "/AlertSettings?AlertEnabled=" + isAlertsEnabled);

                };
                /////////////////////END DONE///////////////////////////////////////////////////////////
                function _GetWeatherDetails(siteId) {
                   return $http.get(data + "/" + siteId + "/Weather");
               

                };
                function _SaveSiteWeatherSettings(siteId,Data1) {

                    var obj = {};
                    obj.body = Data1;
                  return $http.post(data + "/" + siteId + "/Weather/Settings/", obj);
                  
                };
                function _GetDeviceType(deviceId) {
                    return $http.get(dataDevice + "/" + deviceId + "/Type");


                };
              
                function _getSiteName(siteId) {
                    //return $http.get(data + "/" + siteId + "/Info");
                    return $http.get(server_MF_api + "/Site/" + siteId + "/Info");
                  
                };
                function _changeSiteName(id, name) {
                    //return $http.post(data + '/' + id + '?SiteName=' + name);
                    return $http.post(server_MF_api + '/Site/' + id + '?SiteName=' + name);
                };
              
                function _DeleteSite(id) {
                  //  return $http.delete(data + '/' + id);
                    return $http.delete(server_MF_api + '/Site/' + id);
                };
                function _getSharingList(id) {
                    return $http.get(data + "/" + id + "/Users");
                };
                function _sendShareUser(id,data1) {
                    return $http.post(data + "/" + id + "/Users", data1);
                };
                function _deleteUser(siteId , userId) {
                    return $http.delete(data + "/" + siteId + "/Users?LinkedUserID=" + userId);
                };
                function _transferProject(id, email) {
                    return $http.post(data + "/" + id + "/Transfer?Email="+email);
                };
                function _getTransferStatus(id) {
                    return $http.get(data + "/" + id + "/Transfer");
                };
                function _cancelTransfer(id) {
                    return $http.delete(data + "/" + id + "/Transfer");
                };
                function _localTransfer(sId,target) {
                    return $http.post(data + "/" + sId + "/LocalTransfer?ProjectID=" + target);
                };


                function _GetDeviceInfo(deviceId) {
                    return $http.get(server_MF_api + "/Device/" + deviceId + "/Info");
                    //return $http.get(dataDevice + "/" + deviceId + "/Info");


                };
                function _getSessonList(siteID) {
                    return $http.get(data + "/" + siteID + "/SessionSetting");


                };
                function _saveSessonList(siteID, sessonList) {
                    return $http.post(data + "/" + siteID + "/SessionSetting",sessonList);
                };
              
                 function _getOneSesson(siteID , sessionID) {
                    return $http.get(data + "/" + siteID + "/SessionSetting/" + sessionID);
                };
                function _saveOneSesson(siteID, sessionID, obj) {
                    return $http.post(data + "/" + siteID + "/SessionSetting/" + sessionID,obj);
                };
                function _changeDeviceName(sn,name) {
                    return $http.post(dataDevice + "/" + sn+"/?name="+name);
                };
                function _getSiteOnlineStatus(sn) {
                    return $http.get(onlineServer + "/siteDevices/?siteId=" + sn);
                };
                function _saveDeviceLocation(sn, lat , lan) {
                    return $http.post(server_MF_api + "/Device/" + sn + '/Location', { Latitude: lat, Longitude: lan });
                    //return $http.post(dataDevice + "/" + sn + '/Location', { Latitude: lat, Longitude: lan });
                };



               

                //interface
                return {

                    GetControllersLocation: _GetControllersLocation,
                    SaveSiteLocation: _SaveSiteLocation,
                    SaveSiteDeviceChangeLocation: _SaveSiteDeviceChangeLocation,
                    GetDeviceInfo:_GetDeviceInfo,
                    GetsiteConT: _GetsiteConT,
                    CreateNewSite: _CreateNewSite,
                    switchDeviceAlerts:_switchDeviceAlerts,
                    GetWeatherDetails: _GetWeatherDetails,
                    SaveSiteWeatherSettings: _SaveSiteWeatherSettings,
                    GetDeviceType:_GetDeviceType,
                    getSiteName: _getSiteName,
                    changeSiteName: _changeSiteName,
                    DeleteSite: _DeleteSite,
                    getSharingList: _getSharingList,
                    sendShareUser: _sendShareUser,
                    deleteUser: _deleteUser,
                    transferProject: _transferProject,
                    getTransferStatus: _getTransferStatus,
                    cancelTransfer: _cancelTransfer,
                    localTransfer: _localTransfer,
                    getSessonList: _getSessonList,
                    saveSessonList: _saveSessonList,
                    getOneSesson: _getOneSesson,
                    saveOneSesson: _saveOneSesson,
                    changeDeviceName: _changeDeviceName,
                    saveDeviceLocation:_saveDeviceLocation,
                    getSiteOnlineStatus: _getSiteOnlineStatus

                    
                   


                };
            }
        }
    }
})(angular);