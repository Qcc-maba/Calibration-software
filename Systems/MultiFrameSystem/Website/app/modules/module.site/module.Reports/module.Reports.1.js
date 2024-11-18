angular.module("module.site.reports",
    [
          "ui.router"
    ])
.config(['$stateProvider', '$urlRouterProvider', function ($stateProvider, $urlRouterProvider) {

    $urlRouterProvider
    $stateProvider
      .state('site.reports', {
          url: '/reports',
          template: '<div reports></div>',
          controller: ['$scope', '$stateParams', function ($scope, $stateParams) {
              //$scope.siteId = $stateParams.siteId;
              $("#splash-page").css("display", "none");
          }]
      })

}]);