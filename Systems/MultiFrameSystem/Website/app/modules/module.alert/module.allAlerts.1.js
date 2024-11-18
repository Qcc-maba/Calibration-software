(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.allAlerts', []);

})(angular);

angular.module("module.allAlerts",
    [
          "ui.router"

    ])
.config(['$stateProvider',function ($stateProvider) {
    $stateProvider
      .state('alerts', {
          url: '/alerts',
          views: {
              'root@': {
                  template: '<div all-alerts></div>',
                  controller: function () {
                  
                      $("#splash-page").css("display", "none");
                  }
              }
          }
      })
}]);