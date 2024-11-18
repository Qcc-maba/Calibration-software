angular.module("module.site.settings",
    [
          "ui.router"
    ])
.config(['$stateProvider', '$urlRouterProvider', function ($stateProvider, $urlRouterProvider) {

    $urlRouterProvider
    $stateProvider
      .state('site.settings', {
          url: '/settings',
          template: '<div ng-if="siteId && startSite" site-ad-d ng-model="siteId"></div>',
          controller:['$scope','$stateParams' ,function ($scope, $stateParams) {
              $scope.siteId = $stateParams.siteId;
              $("#splash-page").css("display", "none");
          }]
      })
    
}]);