(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.XCI.Device')
        .directive('onlineDirective', onlineDirectiveFactory);
    /*********************************************************************Online****************************************************************************************************/
    function onlineDirectiveFactory() {
        var OnlineEvents = ['1000', '1011', '2301', '3001', '3002', '3003', '2000', '2001', '2002', '2003', '2004'];


        return {
            restrict: 'EA',

            templateUrl: 'app/modules.devices/XCI.Device/online/device.online.html',

            controller: ['$scope', 'deviceProxy', '$state', 'mainProvider', 'onlineProvider', '$filter', function ($scope, deviceProxy, $state, mainProvider, onlineProvider, $filter) {

                const MAX_DIFF_ZONES_UPDATE = 20;
                $scope.device = mainProvider.CurrentDevice.data;
                $scope.timer = false;
                $scope.alertCode = null;
                $scope.currentRuns = [];
                $scope.currentZone = { index: -1, URL: "", name: "" };
                var changeImage = 0;
                $scope.flipValue = 0;
                var deviceAlertsCodeArr = [];
                //****************************************************************
                function stringTimeToSeconds(strTime) {
                    if (!strTime) {
                        return 0;
                    }
                    return parseInt(strTime.Hours) * 3600 + parseInt(strTime.Minutes) * 60 + parseInt(strTime.Seconds);
                }
                //****************************************************************
                $scope.getZone = function (zoneId, zoneName) {
                    $scope.currentZoneManual = { zoneId: zoneId, zoneName: zoneName };
                }
                //**************************************************************
                $scope.startManualOperation = function (time, zoneNumber) {

                    var zoneNum = zoneNumber || $scope.currentZoneManual.zoneId;
                    deviceProxy.manualZoneOperationOnline($scope.deviceId, zoneNum, stringTimeToSeconds(time))
                        .success(function (data, status, headers, config) {

                        }).error(function (data, status, headers, config) {

                        });

                    //*****************
                    $('#setZoneTime').modal('hide');
                }
                //***************************************************************
                function buildStringFromArray(arr, filterBy) {
                    var str = "";
                    for (var i = 0; i < arr.length; i++) {
                        var val = $filter('translate')(filterBy + arr[i])
                        if (str == "") {
                            str = val;
                        } else {
                            str = str + ' ,' + val;
                        }

                    }
                    return str;
                }
                //*************************************************************
                $scope.resetAlrts = function () {
                    //service missing
                }
                //*************************************************************
                $scope.changeCurrentRunningZone = function (index) {
                    var temp = $scope.currentRuns[0];
                    $scope.currentRuns[0] = $scope.currentRuns[index];
                    $scope.currentRuns[index] = temp;
                }
                //*************************************************************
                function onlineCBfuncOnlinePage(data) {
                    var original = String(data.code);
                    var prefix = original.substring(0, 2);
                    switch (prefix) {


                        case "10": // connection , pause , sync

                            if (original == "1000") {   // connection , pause

                                if (data.connection) {   // active
                                    $("div[onlinetarget='deviceStatus']").addClass('active');
                                }
                                if (!data.connection) { // offline
                                    $("div[onlinetarget='deviceStatus']").removeClass('active');
                                }
                                if (data.connection && data.status == 1) {  //pause
                                    $("div[onlinetarget='pause']").addClass('active');
                                }
                                if (data.connection && data.status == 0) {  //pause
                                    $("div[onlinetarget='pause']").removeClass('active');
                                }
                            }
                            if (original == "1011") { //sync
                                if (data.isSync) {
                                    $("div[onlinetarget='sync']").addClass('active');
                                }
                                if (!data.isSync) {
                                    $("div[onlinetarget='sync']").removeClass('active');
                                }
                            }
                            break;



                        case "23": // Digital Input state (single input)

                            if (original == "2301") { // rain sennsor
                                if (data.state) {
                                    $("div[onlinetarget='rain']").addClass('active');
                                }
                                if (!data.state) {
                                    $("div[onlinetarget='rain']").removeClass('active');
                                }
                            }
                            break;

                        case "30":  //Water Meter
                            if (original == "3001") {
                                $scope.maValue = data.value;
                              //  $scope.$apply();
                            }
                            if (original == "3002") {
                                $scope.gpmValue = data.value;
                              //  $scope.$apply();
                            }
                            if (original == "3003") {
                                $scope.flipValue = data.value;
                           //     $scope.$apply();
                            }
                            break;

                        case "20":  //Alerts
                            if (data.state) {
                                $("div[onlinetarget='alert']").addClass('active');
                                if (deviceAlertsCodeArr.indexOf(original) == -1) {
                                    deviceAlertsCodeArr.push(original);
                                }
                            }
                            if (!data.state) {
                                var index = deviceAlertsCodeArr.indexOf(original);
                                deviceAlertsCodeArr.splice(index, 1);
                                if (deviceAlertsCodeArr.length == 0) {
                                    $("div[onlinetarget='alert']").removeClass('active');
                                }
                            }

                            $scope.alertCoded = buildStringFromArray(deviceAlertsCodeArr, "MF_ALERTS_ALERTS_CODE_");
                         //   $scope.$apply();
                            break;
                        case "40":  //Zones
                            var zoneNumber = parseInt(original.substring(2));
                            calcZoneTimeLeft($scope.zonesList[zoneNumber-1], data);

                          //  $scope.$apply();
                            break;


                    }
                }
                //****************************************************************
                function parseSecondsToStringDate(sec) {
                    var seconds = Math.floor(sec % 60).toString();
                    var minutes = Math.floor((sec / 60) % 60).toString();
                    var hours = Math.floor((sec / (60 * 60)) % 24).toString();
                    if (seconds.length == 1) {
                        seconds = '0' + seconds;
                    }
                    if (minutes.length == 1) {
                        minutes = '0' + minutes;
                    }
                    if (hours.length == 1) {
                        hours = '0' + hours;
                    }
                    return hours + ':' + minutes + ':' + seconds
                }
                //***************************************************************
                function calcZoneTimeLeft(zone, event) {
                    var timeLeft_Sec = event.timeUnit == 'minute' ? event.timeLeft * 60 : event.timeLeft;

                    var serverUTC = new Date().getTime() + onlineProvider.getDiffUTC();  // server current time
                    var deffBetweenLastUbdateToEventTime = (serverUTC - event.lastUpdate);
                    var newTimeLeft = timeLeft_Sec - (deffBetweenLastUbdateToEventTime / 1000);  //ex' last update 8:00:00 time left 7 min  ; now 08:00:30 ---> deffBetweenLastUbdateToEventTime = 30   ---> newTimeLeft = 6:30 minutes
                    if (newTimeLeft < 2) {
                        zone.timeLeftStr = null;
                        var ind = $scope.currentRuns.indexOf(zone.zoneNumber - 1);
                        $scope.currentRuns.splice(ind, 1);
                        return;
                    }

                    //calc the diff between the two:
                    //      a. local time left (timeLeft_Sec changed by timer)
                    //      b. server time left (newTimeLeft, calculted using the onlineProvider.getDiffUTC())
                    var diffTimeLeft = zone.timeLeftStr ? Math.abs(newTimeLeft - zone.timeLeft_Sec) : MAX_DIFF_ZONES_UPDATE + 1;

                    if (diffTimeLeft > MAX_DIFF_ZONES_UPDATE) {
                        zone.timeLeft_Sec = newTimeLeft;
                        zone.timeLeftStr = parseSecondsToStringDate(newTimeLeft);
                    }
                }
                //***************************************************************
                function intervalFunction(zonesList, currentZone, currentRuns) {

                    changeImage++;
                    for (var i = 0; i < zonesList.length; i++) {
                        if (zonesList[i].timeLeftStr) {
                            if (zonesList[i].timeLeft_Sec > 1) {
                                if (currentRuns.indexOf(i) == -1) { // new zone running push index to array
                                    currentRuns.push(i);
                                }
                                zonesList[i].timeLeft_Sec--;
                                zonesList[i].timeLeftStr = parseSecondsToStringDate(zonesList[i].timeLeft_Sec);
                            } else {
                                zonesList[i].timeLeftStr = null;
                                var removeIndex = currentRuns.indexOf(i);
                                currentRuns.splice(removeIndex, 1);
                            }

                        }
                    }
                    if (changeImage % 3 == 0) {
                        if (currentZone.index >= zonesList.length - 1) {
                            currentZone.index = -1;
                        }
                        currentZone.index++;
                        currentZone.URL = zonesList[currentZone.index].imageURI;
                        currentZone.name = zonesList[currentZone.index].name;

                    }
                }
                //***************************************************************
                function addToOnlineArrayZonesEvents(zones) {
                    for (var i = 0; i < zones.length; i++) {
                        OnlineEvents.push(4000 + zones[i].zoneNumber);
                    }
                }
                //**************************************************************
                $scope.getZonesActivateList = function (deviceId) {

                    deviceProxy.getZonesActivateList(deviceId)
                        .success(function (data, status, headers, config) {
                            $scope.zonesList = data.body;
                            addToOnlineArrayZonesEvents(data.body);
                            onlineProvider.registerDevice(OnlineEvents, deviceId, 'DeviceOnline', onlineCBfuncOnlinePage);
                            onlineProvider.registerIntervalCallback(callIntervalFunc);
                            fixLoadingOff();
                        }).error(function (data, status, headers, config) {

                        });
                }
                //***************************************************************
                $scope.goToZone = function (zoneId) {
                    $state.go('device.XCI_device.zones.adviser', { zoneId: zoneId });
                }
                //*******************************************************
                $scope.maObj = {
                    "data": { "Label": "mA", "Value": 0 },
                    "options": { "height": 170, "redFrom": 100, "redTo": 120, "yellowFrom": 75, "yellowTo": 100, "majorTicks": [0, 20, 40, 60, 80, 100, 120], "minorTicks": 7, "max": 120, "min": 0 }
                }
                $scope.gpmObj = {
                    "data": { "Label": "GPM", "Value": 0 },
                    "options": { "height": 170, "redFrom": 90, "redTo": 100, "yellowFrom": 75, "yellowTo": 90, "majorTicks": [0, 20, 40, 60, 80, 100], "minorTicks": 6, "max": 100, "min": 0 }
                }

                //*****************************************************************************
                $scope.goToZone = function (zoneId) {
                    fixLoadingOn("ZoneAdviser");
                    $state.go('device.XCI_device.zones.adviser', { zoneId: zoneId });
                }
                //*****************************************************************************************
                function callIntervalFunc() {
                    intervalFunction($scope.zonesList, $scope.currentZone, $scope.currentRuns);
                }
                //********************************************************
                
            }],
            link: function (scope, element, attrs) {

                scope.getZonesActivateList(scope.deviceId);

            }




        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);








