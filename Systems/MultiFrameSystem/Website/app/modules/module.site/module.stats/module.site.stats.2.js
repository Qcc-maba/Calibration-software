angular.module("module.site.stats",
    [
          "ui.router"
    ])
.config(['$stateProvider','$urlRouterProvider', function ($stateProvider, $urlRouterProvider) {

    $urlRouterProvider
   .when('project/:projectId/site/:siteId/stats', 'project/:projectId/site/:siteId/stats/list');

    $stateProvider
      .state('site.stats', {
          url: '/stats',
          templateUrl: 'app/modules/module.site/module.stats/stats.html',
          controller: ['$scope', '$state',
                      function ($scope, $state) {
                          $scope.goTo = function (action) {

                              fixLoadingOn(action);
                              switch (action) {
                                  case "SList":
                                      $state.go('site.stats.list');
                                      break;
                                  case "SGeneral":
                                      $state.go('site.stats.general');
                                      break;
                                  case "SCharts":
                                      $state.go('site.stats.charts');
                                      break;
                              }
                          }

                      }]
      })
     .state('site.stats.list', {
         url: '/list',
         templateUrl: 'app/modules/module.site/module.stats/statsList.html',
         controller: ['$scope', '$stateParams',
               function ($scope,   $stateParams) {
                    $scope.siteId = $stateParams.siteId;
                    $("#splash-page").css("display", "none");
                    setLastAction("SList");
        }]

     })
         .state('site.stats.general', {
             url: '/general',
             template: '<div general ng-model="siteId" type="site"></div>',
             controller: ['$scope', '$stateParams',
                   function ($scope, $stateParams) {
                       $scope.siteId = $stateParams.siteId;
                       $("#splash-page").css("display", "none");
                       setLastAction("SGeneral");
                   }]

         })
     .state('site.stats.charts', {
         url: '/charts',
         template: '<div charts-directive ng-model="siteId"></div>',
         controller: ['$scope', '$stateParams', 
            function ($scope, $stateParams) {
                $scope.siteId = $stateParams.siteId;
                $("#splash-page").css("display", "none");
                setLastAction("SCharts");
            }]

     })
   
}]);