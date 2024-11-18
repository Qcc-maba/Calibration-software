angular.module("module.GSI.Device", [
     "ui.router"
    , "module.widgets"
    , "colorpicker.module"
    ,"module.httpProxies"])
.config(['$stateProvider',function ($stateProvider) {
    $stateProvider
    .state('device.GSI_device', {
        url: '/GSI',
        views: {
            '': {
                templateUrl: 'app/modules.devices/GSI.Device/GSI.device.html',
                controller: ['$scope', '$stateParams', '$state', function ($scope, $stateParams, $state) {
            
                    $("#splash-page").css("display", "none");
                    $scope.siteId = 992;
                    /*****************************************************************/
                    $scope.goTo = function (action) {

                       // fixLoadingOn(action);
                        switch (action) {
                            
                            case "status":

                                $state.go('device.GSI_device.status');
                                break;
                            case "programs":
                                $state.go('device.GSI_device.programs');
                                break;
                            case "settings":
                                $state.go('device.GSI_device.settings.unit');
                                break;
                            case "reports":
                                $state.go('device.GSI_device.reports');
                                break;
                            case "generalLogs":
                                $state.go('device.GSI_device.generalLogs');
                                break;
                            
                        }
                    }
                }
            ]}
        }
    })
   .state('device.GSI_device.reports', {
       url: '/reports',
       views: {
           '': {
               template: '<div reports ng-model="deviceId"></div>',
               controller: ['$scope', '$stateParams', function ($scope, $stateParams) {
                   $scope.deviceId = $stateParams.deviceId;
              
               }
           ]}
       }
   })
   .state('device.GSI_device.status', {
       url: '/status',
       views: {
           '': {
               template: '<div status></div>',
               controller: ['$scope', '$stateParams', function ($scope, $stateParams) {
                   $scope.deviceId = $stateParams.deviceId;

                   $("#splash-page").css("display", "none");
               }
           ]}
       }
   })
        .state('device.GSI_device.programs', {
            url: '/programs',
            views: {
                '': {
                    template: '<div irrigation-program ng-model="deviceId"></div>',
                    controller: ['$scope', '$stateParams', function ($scope, $stateParams) {
                        $scope.deviceId = $stateParams.deviceId;
                    }
                    ]
                }
            }
        })
    

     .state('device.GSI_device.generalLogs', {
         url: '/generalLogs',
         views: {
             '': {
                 template: '<div general-logs ></div>',
                 controller: ['$scope', '$stateParams', function ($scope, $stateParams) {
                     $scope.deviceId = $stateParams.deviceId;
                 }
                 ]
             }
         }
     })

}]);