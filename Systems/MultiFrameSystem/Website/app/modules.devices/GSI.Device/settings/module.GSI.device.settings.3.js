angular.module("module.GSI.Device.Settings", [
     "ui.router"
    , "module.widgets"
    , "colorpicker.module"
    , "module.httpProxies"])
.config(['$stateProvider', function ($stateProvider) {
    $stateProvider
    .state('device.GSI_device.settings', {
        url: '/settings',
        views: {
            '': {
                templateUrl: 'app/modules.devices/GSI.Device/settings/allSettings.html',
                controller: ['$scope', '$stateParams', '$state', function ($scope, $stateParams, $state) {
                    $scope.deviceId = $stateParams.deviceId;
                    $scope.goTo = function (action) {

                        //fixLoadingOn(action);
                        switch (action) {
                            case "Alerts":
                                $state.go('device.GSI_device.settings.alerts');
                                break;
                            case "Units":

                                $state.go('device.GSI_device.settings.unit');
                                break;
                            case "Stations":
                                $state.go('device.GSI_device.settings.stations');
                                break;
                        
                        }
                    }
                    $("#splash-page").css("display", "none");
                }
                ]
            }
        }
    })
   .state('device.GSI_device.settings.alerts', {
       url: '/alerts',
       views: {
           '': {
               template: '<div alerts-settings></div>',
               controller: ['$scope', '$stateParams', function ($scope, $stateParams) {
                   $scope.deviceId = $stateParams.deviceId;

               }
               ]
           }
       }
   })
    .state('device.GSI_device.settings.stations', {
        url: '/stations',
        views: {
            '': {
                template: '<div station-settings></div>',
                controller: ['$scope', '$stateParams', function ($scope, $stateParams) {
                    $scope.deviceId = $stateParams.deviceId;

                }
                ]
            }
        }
    })
    .state('device.GSI_device.settings.unit', {
        url: '/unit',
        views: {
            '': {
                template: '<div unit-settings></div>',
                controller: ['$scope', '$stateParams', function ($scope, $stateParams) {
                    $scope.deviceId = $stateParams.deviceId;

                }
                ]
            }
        }
    })
   

}]);