angular.module("module.XCI.zones", [
     "ui.router"
     , "ngSimpleUpload"
    , "module.widgets"
    , "colorpicker.module"
    , "module.httpProxies"])
.config(['$stateProvider', function ($stateProvider) {
    $stateProvider

    .state('device.XCI_device.zones', {
        url: '/zones/:zoneId',
        views: {
            'root@': {
                templateUrl: 'app/modules.devices/XCI.Device/module.XCI.zone/XCI.zone.html',
                controller: ['$scope', '$stateParams', '$state', 'siteProxy','baseProxy', 'zoneProxy', function ($scope, $stateParams, $state, siteProxy,baseProxy, zoneProxy) {
                    $scope.deviceId = $stateParams.projectId;
                    $scope.siteId = $stateParams.siteId;
                    $scope.deviceId = $stateParams.deviceId;
                    $scope.zoneId = $stateParams.zoneId;
                    baseProxy.Global.data.serverXci + '/Admin/Zone'
                    $scope.imgUrl = baseProxy.Global.data.serverXci + '/Admin/Zone/' + $scope.deviceId + "/" + $scope.zoneId + "/ImageUpload";
                  
                    
                    siteProxy.GetDeviceInfo($stateParams.deviceId)
                       .success(function (data) {
                           $scope.device = data.body;
                           for (var i = 0 ; i < data.body.otherDevicesView.length ; i++) {
                               if (data.body.otherDevicesView[i].sn == $scope.deviceId) {
                                   $scope.device.deviceName = data.body.otherDevicesView[i].name;
                               }
                           }
                       }).error(function (data, status, headers, config) {
                           toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
                       });
                    //@@@@@@ get Zone name
                    zoneProxy.getZoneInfo($scope.deviceId, $scope.zoneId)
                    .success(function (data) {
                        $scope.zone = data.body;

                    });

                    //************************************************
                   

                    
                 
                    $scope.goToPage = function (action, param1) {

                        fixLoadingOn(action, param1);
                        switch (action) {

                            case "project":
                                $state.go('site.preview.map', { siteId: $scope.device.parentSiteInfo.projectID });
                                break;
                            case "site":
                                $state.go('site.preview.map', { siteId: $scope.device.parentSiteInfo.siteID });
                                break;
                            case "device":
                                $state.go('device.XCI_device.online', {deviceId: $scope.deviceId});
                                break;

                        }
                    }

                    $scope.openZoneImgModal = function () {
                        $scope.openModal = true;
                    }
                    $("#splash-page").css("display", "none");
                }
                ]
            }
        }
    })
     .state('device.XCI_device.zones.adviser', {
         url: '/adviser',
         views: {
             '': {
                 template: '<div zones-categories></div>',
                 controller: ['$scope', '$stateParams', function ($scope, $stateParams) {
        
                     closeNavbar();
                     $("#splash-page").css("display", "none");
                 }
                 ]
             }
         }
     })
        
    

}]);