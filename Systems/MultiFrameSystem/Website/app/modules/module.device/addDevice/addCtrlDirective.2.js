
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.device')
        .directive('addCtrl', addCtrlDFactory);
    /*********************************************************************************************************************************************************************/
    function addCtrlDFactory() {
        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.device/addDevice/addCtrl.html',
            controller: ['$scope', '$window', '$stateParams', '$state', 'baseProxy', 'deviceProxy', 'zoneProxy', 'directiveComm', '$filter', function ($scope, $window, $stateParams, $state, baseProxy, deviceProxy, zoneProxy, directiveComm, $filter) {
                //*************************************************Attributs******************************
                var myLocation = {};
                $scope.tempSn = '';
                $scope.step = 'deviceSettings';
                $scope.zonesNum = [];
                $scope.validation = {
                    name:false
                }
                $scope.tempName = '';
                $scope.blockedSN = false;
                $scope.siteId = $stateParams.siteId;
                $scope.connector = directiveComm.CreateConnector();
                $scope.connector.SetCallbackUp(function (location) {
                    $scope.ctrlDetails.location.latitude = location.lat();
                    $scope.ctrlDetails.location.longitude = location.lng();
                });

                $scope.ShowMap = false;
                $scope.openModal = function () {
                    $scope.ShowMap = true;
                    ///show modal
                    $('#addCtrl').modal('toggle');

                };
                $scope.closeModal = function () {
                   
                    $scope.tempName = '';
                    $scope.blockedSN = false;
                    $scope.snERROR = false;
                    $scope.tempSn = '';
                    $scope.step = 'deviceSettings';
                    if ($scope.ctrlDetails && $scope.ctrlDetails.latitud) {
                        myLocation.latitude = $scope.ctrlDetails.latitude;
                        myLocation.longitude = $scope.ctrlDetails.longitude;
                    }
             
                    $scope.ctrlDetails = null;
                    $('#addCtrl').modal('toggle');
                };
                $scope.ladda = {
                    SaveNewCtrl: false,
                    go: false,
           
                };
               
             
                //***********************************************************Function**********************

                function buildZonesArray() {
                    while (i < $scope.ctrlDetails.activeZones) {
                        $scope.zonesNum.push(i);
                        i += 2;
                    }
                    $scope.zonesNum.push($scope.ctrlDetails.activeZones)
                }
            
                navigator.geolocation.getCurrentPosition(function (location) {
                    myLocation.latitude = location.coords.latitude;
                    myLocation.longitude = location.coords.longitude;
                });

              
           
                //***********************************************************SaveNewDevice(Outer)**********************
                $scope.SaveNewDevice = function (form) {
                    if (form) {
                        $scope.validation.name = false;
                        $scope.ctrlDetails.deviceName = $scope.tempName;
                        //if($scope.isDeviceSetBefore){}


                        $scope.ladda.SaveNewCtrl = true;
                        deviceProxy.NewCtrlSave($scope.ctrlDetails)
                        .success(function (data, status, headers, config) {
                            if (data.body.selfOwned == false && data.body.systemDeviceType.name == 'XCI-WIFI') {
                                $scope.step = 'wifiConfig';
                            } else {
                            
                                $state.go('device', { deviceId: data.body.sn })
                            }

                            toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                            $scope.ladda.SaveNewCtrl = false;
                        }).error(function (data, status, headers, config) {
                            toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
                            $scope.ladda.SaveNewCtrl = false;
                        });
                    
                    } else {
                        $scope.validation.name = true;
                    }
                    
                   
                }
                $scope.goToDevice = function(){
                    $state.go('device', { deviceId: $scope.ctrlDetails.sn });
                }
                $scope.goToNetwork = function () {
                    
                    $window.open(ROOT_ADDR.SYSTEM_MF_ROOT + '/cyberRainWifi.html');
                }
                function alphanumeric(inputtxt)  
                {  
                    var letterNumber = /[^a-z\d]/i;
                    if(!letterNumber.test(inputtxt))   
                    {  
                        return true;  
                    }  
                    else  
                    {   
                        
                        return false;   
                    }  
                } 
                $scope.$watch('tempSn', function (nVal, oVal) {
                    if ((nVal !== oVal)) {
                        $scope.snERROR = true;
                        if (nVal && nVal.length == 16 && alphanumeric(nVal)) {

                            $scope.snERROR = false;
                            deviceProxy.SnValidation(nVal)
                                 .success(function (data, status, headers, config) {
                                     if (data.result && data.body.status == true) {
                                 
                                         $scope.blockedSN = true;
                                         $scope.ctrlDetails = {
                                             parentSiteID: $scope.siteId,
                                             sn: nVal,
                                             deviceName: '',
                                             activeZones: data.body.maxZones,
                                             location: {
                                                 latitude: myLocation.latitude || 32,
                                                 longitude: myLocation.longitude || 35
                                             }

                                         };


                                     buildZonesArray();
                                     }

                                 })
                                 .error(function (data, status, headers, config) {
                                     toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
                                 });

                           
                        


                            
                        }
                      
                        
                   
                       
                    }
                });
             
            }
        ]};
    }

    /*******************************************************************************************************************************************************************************/

})(angular);






