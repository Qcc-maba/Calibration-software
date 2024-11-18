
(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.main')
        .provider('onlineProvider', onlineProvider);



    //////////////// JavaScript //////////////


    function onlineProvider() {


        return {
            $get: function (siteProxy, deviceProxy, $interval) {

                var callbacks = [];
                var socket;
                var onlineList = null;
                var onlineDevice = null;
                var siteId = null;
                var deviceId = null;
                var diffUTC = {def:0}; // miliseconds 1000 = 1 sec
   

                function _getDiffUTC() {
                    return diffUTC.def;
                }
                //******************************
                function _setDiffUTC(diffUtc) {
                    diffUTC.def = diffUtc;
                }
                //*****************************************
                function publishDeviceEvents(callback, pObj) {
                    for (var i = 0; i < pObj.events.length; i++) {
                        pObj.events[i].data.sn = pObj.sn;
                        _callCode(pObj.events[i].code, pObj.events[i].data, callback);
                    }
                }
                //******************************************
                function publishDevicesCachedEvents(callback) {
                    for (var i = 0 ; i < onlineList.length ; i++) {
                        publishDeviceEvents(callback, onlineList[i]);
                    }
                }
                //******************************************
                function _init(ServerUrl, Token) {
                    var options = {
                        transports: ['polling'],
                        query:
                        {
                            clientTime: new Date().getTime(),
                            Token: Token

                        }
                    };
                    socket = io.connect(ServerUrl, options);

                    //***************************************
                    socket.on('server_ready', function (data) {
                     
                        _setDiffUTC(data.diffUTC);
                     
                    });
                    socket.on('reconnect_failed', function () {
                        alert('online server connection failed!')
                    });
                    socket.on('site_event', function (data) {
                        data.event.sn = data.sn;
                        _callCode(data.code, data.event);

                    });
                    socket.on('device_event', function (data) {
                        data.event.sn = data.sn;
                        _callCode(data.code, data.event);
                    });


                }
                //************************************************
                function _findCallback(codesArr, id, who, fn) {
                    var callbackObject = null;
                    for (var i = 0; i < callbacks.length; i++) {
                        if (callbacks[i].componnent == who) {
                            callbackObject = callbacks[i];
                            callbackObject.callback = fn;
                            callbackObject.isPublish = false;
                            break;
                        }
                    }
                    if (!callbackObject) {

                        callbackObject = { callback: fn, codes: codesArr, componnent: who, isPublish: false };
                        callbacks.push(callbackObject);
                    }

                    return callbackObject;
                }
                //**********************************************
                function _resetState() {
                    callbacks = [];
                    onlineList = null;
                    onlineDevice = null;
                    siteId = null;
                    deviceId = null;
                }
                //********************************************
                function _registerSite(codesArr, id, who, fn) {
                    if (siteId != id) {
                        _resetState();
                        siteId = id;
                        _startSite(siteId);
                    }
                    var callbackObject = _findCallback(codesArr, id, who, fn);

                    var now = new Date().getTime();

                    if (onlineList) { // get from server 
                        if (now - onlineList.time > 3000) { // the onlineList is not enogth updated                            
                            _getSiteOnlineStatus();
                        } else {
                            publishDevicesCachedEvents(callbackObject);
                        }

                    }
                }
                //***********************************************
                function _registerDevice(codesArr, id, who, fn) {

                    if (deviceId != id) {
                        _resetState();
                        deviceId = id;
                    
                        _startDevice(deviceId);
                    }

                    var callbackObject = _findCallback(codesArr, id, who, fn);

                    var now = new Date().getTime();
                    if (onlineDevice) { // get from server 
                        if (now - onlineDevice.time > 3000) { // the onlineList is not enogth updated
                            _getDeviceOnlineStatus();
                        } else {
                            publishDeviceEvents(callbackObject, onlineDevice);
                        }
                    }
                }
                //********************************************
                function _callCode(code, data, callback) {
                    if (callback) {
                        for (var j = 0; j < callback.codes.length ; j++) {
                            if (callback.codes[j] == code) {
                                data.code = code;
                                callback.callback(data);
                                break;
                            }
                        }
                    } else {
                        for (var i = 0; i < callbacks.length; i++) {
                            for (var j = 0; j < callbacks[i].codes.length ; j++) {
                                if (callbacks[i].codes[j] == code) {
                                    data.code = code;
                                    callbacks[i].callback(data);
                                    break;
                                }
                            }
                        }
                    }
                }
                //*******************************************
                function _startDevice(deviceID) {
                    onlineDevice = null;
                    socket.emit('register_device', deviceID);
                    _getDeviceOnlineStatus();
                }
                //************************************
                function _startSite(siteID) {
                    onlineList = null;
                    socket.emit('register_site', siteID);
                    _getSiteOnlineStatus();
                }
                //************************************
                function _getSiteOnlineStatus() {
                    siteProxy.getSiteOnlineStatus(siteId)
                      .success(function (data) {
                          data.time = new Date().getTime(); //time of object last update
                          onlineList = data;

                          // run on all calbackes if we have callback that didnt published than publish now
                          for (var i = 0; i < callbacks.length; i++) {
                              if (!callbacks[i].isPublish) {
                                  publishDevicesCachedEvents(callbacks[i]);
                              }
                          }
                      });
                }
                //******************************************
                function _getDeviceOnlineStatus() {
                    deviceProxy.getDeviceOnline(deviceId)
                        .success(function (data, status, headers, config) {
                            data.time = new Date().getTime(); //time of object last update
                            onlineDevice = data;
                    

                            // run on all calbackes if we have callback that didnt published than publish now
                            for (var i = 0; i < callbacks.length; i++) {
                                if (!callbacks[i].isPublish) {
                                    publishDeviceEvents(callbacks[i], onlineDevice);
                                }
                            }
                        }).error(function (data, status, headers, config) {

                        });
                }


                //*******************************************
                function _registerIntervalCallback(intervalCallback) {
                    intervalFunc = intervalCallback;
                }
                //********************************************
                function intervalFunc() {
                    return true;
                }
                //*******************************************
                var updateZonesInterval = $interval(function () {
                    intervalFunc();
                }, 1000);

                //interface
                return {
                    init: _init,
                    registerSite: _registerSite,
                    registerDevice: _registerDevice,
                    getDiffUTC: _getDiffUTC,
                    registerIntervalCallback: _registerIntervalCallback
              


                };
            }
        }
    }
})(angular);