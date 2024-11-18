angular.module("module.admin",
    [
          "ui.router"
       
    ])
.config(function ($stateProvider, $urlRouterProvider) {

  

  

    $stateProvider
      .state('admin', {
          url: '/admin',
          views: {
              'root@': {
                  template: '<div class="adminMain" ui-view=""></div>',
                  controller: function ($scope, $stateParams, $state) {
                      $("#splash-page").css("display", "none");
                      $("#navbar").css("display", "block");
                      $('.main-content').css("marginLeft", '0px');
                  }
        
              }
           
          }
      })
    $stateProvider
      .state('admin.users', {
          url: '/users',
          template: '<div users></div>',
          controller: ['$scope', '$stateParams', '$state',
               function ($scope, $stateParams, $state) {
                  
                   $("#splash-page").css("display", "none");
               }]

     
      })
    $stateProvider
   .state('admin.user', {
       url: '/user/:email',
       template: '<div user></div>',
       controller: ['$scope', '$stateParams', '$state',
          function ($scope, $stateParams, $state) {

              $("#splash-page").css("display", "none");
          }]


    })
     //.state('admin.roles', {
     //    url: '/roles',
     //    template: '<div roles></div>',
     //    controller: ['$scope', '$stateParams', '$state',
     //          function ($scope, $stateParams, $state) {
                  
     //              $("#splash-page").css("display", "none");
     //          }]

     //})
     //  .state('admin.language', {
     //      url: '/language',
     //      template: '<div language></div>',
     //      controller: ['$scope', '$stateParams', '$state',
     //            function ($scope, $stateParams, $state) {

     //                $("#splash-page").css("display", "none");
     //            }]

     //  })
});
