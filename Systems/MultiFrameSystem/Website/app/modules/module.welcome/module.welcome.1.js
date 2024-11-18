
angular.module("module.welcome",
    [
          "ui.router"

    ])
.config(function ($stateProvider, $urlRouterProvider) {

    $urlRouterProvider


    $stateProvider
      .state('welcome', {
          url: '/welcome',
          views: {
              'root@': {
                  templateUrl: 'app/modules/module.welcome/welcome.html',
                  controller: ['$scope', '$stateParams', '$state','user',
                      function ($scope, $stateParams, $state, user) {
                          $scope.user = user.getUser();
                          $("#splash-page").css("display", "none");
                          closeNavbar();
                       
                      }]
              }
              //'navbar@': {
              //    templateUrl: 'app/modules/module.navbar/navbar.html',
              //}


          }
      })

     



});