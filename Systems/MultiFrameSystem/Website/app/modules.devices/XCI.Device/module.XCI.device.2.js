angular.module("module.XCI.Device", [
     "ui.router"
    , "module.widgets"
    , "colorpicker.module"
    ,"module.httpProxies"])
.config(['$stateProvider',function ($stateProvider) {
    $stateProvider
    .state('device.XCI_device', {
        url: '',
        views: {
            '': {
                templateUrl: 'app/modules.devices/XCI.Device/XCI.device.html',
                controller: ['$scope', '$stateParams', '$state', 'user', 'onlineProvider', 'mainRouter', function ($scope, $stateParams, $state, user, onlineProvider, mainRouter) {
                    mainRouter.callkey("logo", 'logo.png');
                    $scope.deviceId = $stateParams.deviceId;
                    $scope.siteId = $stateParams.siteId;
                    $scope.projectId = $stateParams.projectId;

                    $scope.privilige = user.getSharingData().sharingData.roleModify;
                    $("#splash-page").css("display", "none");

                    //*******************OnlineStart*******************************
                  //  onlineProvider.startDevice($scope.deviceId);
                    //*************************goTo************************
                    $scope.goTo = function (action , param1) {

                        fixLoadingOn(action, param1);
                        switch (action) {
                            case "DView":
                                $state.go('device.XCI_device.view');
                                break;
                            case "DOnline":
                                $state.go('device.XCI_device.online');
                                break;
                        }
                    }
                    //*************************************************
                    $scope.DeleteDevice = function(deviceId) {
                        //missing service
                        //siteProxy.DeleteDevice(deviceId)
                        //  .success(function (data, status, headers, config) {

                        //  })
                        //  .error(function (data, status, headers, config) {

                        //  });
                    }
                }
            ]}
        }
    })
   .state('device.XCI_device.view', {
       url: '/view',
       views: {
           '': {
               template: '<div device-view ng-model="deviceId"></div>',
               controller: ['$scope', '$stateParams', function ($scope, $stateParams) {
                   $scope.deviceId = $stateParams.deviceId;
                   $scope.siteId = $stateParams.siteId;
                   $scope.projectId = $stateParams.projectId;
               }
           ]}
       }
   })
   .state('device.XCI_device.online', {
       url: '/online',
       views: {
           '': {
               template: '<div online-directive></div>',
               controller: ['$scope', '$stateParams', function ($scope, $stateParams) {
                   $scope.deviceId = $stateParams.deviceId;
                   $scope.siteId = $stateParams.siteId;
                   $scope.type = $stateParams.typeName;
                   //$scope.gpmValue = 444;
                   //$scope.mAValue = 124.5;

                   $("#splash-page").css("display", "none");
               }
           ]}
       }
   })
   
        .state('device.XCI_device.stats', {
        url: '/stats',
        templateUrl: 'app/modules/module.stats/stats.html'
    })

}]);