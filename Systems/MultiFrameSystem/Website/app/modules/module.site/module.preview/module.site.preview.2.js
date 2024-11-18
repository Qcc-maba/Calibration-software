angular.module("module.site.preview",
    [
          "ui.router"
    
      
    ])
.config(['$stateProvider','$urlRouterProvider', function ($stateProvider, $urlRouterProvider) {

    $urlRouterProvider
    .when('/project/:projectId/site/:siteId/preview', '/project/:projectId/site/:siteId/preview/map');

    
    $stateProvider
      .state('site.preview', {
          url: '/preview',
          templateUrl: 'app/modules/module.site/module.preview/preview.html',
          controller: ['$scope', '$stateParams', '$state',
                     function ($scope, $stateParams, $state) {
                         $scope.siteId = $stateParams.siteId;
                         $scope.projectId = $stateParams.projectId;
                         $("#splash-page").css("display", "none");
                         $scope.goTo = function (action) {
                             
                             fixLoadingOn(action);
                             switch (action) {
                                 case "Plist":
                                     $state.go('site.preview.list');
                                     break;
                                 case "PMap":

                                     $state.go('site.preview.map');
                                     break;
                                 case "PSquares":
                                     $state.go('site.preview.squares');
                                     break;
                                 case "Graphs":
                                     $state.go('site.preview.graphs');
                                     break;
                                 case "Calandar":
                                     $state.go('site.preview.calandar');
                                     break;
                             }
                         }
                     }]
      })
     .state('site.preview.map', {
         url: '/map',
         template: '<div ng-if="startSite" map-site ng-model="siteId"></div>',
         controller: [function () {
             setLastAction("PMap");
                     }]
     })
     .state('site.preview.list', {
         url: '/list',
         template: '<div ng-if="startSite" site-con-t></div>',
         controller: [function () {
             setLastAction("Plist");
         }]

     })

    .state('site.preview.squares', {
        url: '/squares',
        template: '<div ng-if="startSite" squares></div>',
        controller: [function () {
            setLastAction("PSquares");
        }]
    })
    .state('site.preview.graphs', {
        url: '/graphs',
        template: '<div ng-if="startSite" graph></div>',
        controller: [function () {
            setLastAction("PSquares");
        }]
    })
    .state('site.preview.calandar', {
        url: '/calandar',
        template: '<div ng-if="startSite" calandar></div>',
        controller: [function () {
            setLastAction("PSquares");
        }]
    })
    .state('site.preview.gsiOnline', {
        url: '/gsiOnline',
        template: '<div ng-if="startSite" gsi-online></div>',
        controller: [function () {
            setLastAction("gsi-online");
        }]
    })
}]);