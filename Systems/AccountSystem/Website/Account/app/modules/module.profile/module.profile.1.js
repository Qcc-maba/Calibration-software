angular.module("module.profile",
    [
          "ui.router"

    ])
.config(function ($stateProvider, $urlRouterProvider) {
    $stateProvider
      .state('profile', {
          url: '/profile',
          views: {
              'root@': {
                  template: '<div profile ui-view=""></div>',
                  controller: function ($scope, $stateParams, $state) {
                      $("#splash-page").css("display", "none");
                      $('.main-content').css("marginLeft", '0px');
                  }
              }

          }
      })
   
});
