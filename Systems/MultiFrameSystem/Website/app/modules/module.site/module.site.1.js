angular.module("module.site",
    [
          "ui.router"
        , "module.site.preview"
        , "module.site.stats"
        , "module.site.settings"
        , "module.site.reports"
    ])
.config(['$stateProvider', '$urlRouterProvider', function ($stateProvider, $urlRouterProvider) {

    $urlRouterProvider
        .when('/site/:siteId', '/site/:siteId/preview');
    $stateProvider
      .state('site', {
          url: '/site/:siteId',
          views: {
              'root@': {
                  templateUrl: 'app/modules/module.site/site.html',
                  controller: ['$scope', '$stateParams', '$state', 'coordinator', 'siteProxy','projectProxy','user','mainRouter','mainProvider','onlineProvider',
                      function ($scope, $stateParams, $state, coordinator, siteProxy, projectProxy, user, mainRouter, mainProvider, onlineProvider) {

                          mainRouter.callkey("logo", 'logo_g.png');
                          if ($(window).width() > SMALL_VIEW) {
                              $('#dragbar').css("display", "block");
                              $('.tree').css("width", '225px');
                              $('#dragbar').css("marginLeft", '225px');
                              $('.main-content').css("marginLeft", '225px');
                              $('.navigation-toggler').css("marginLeft", "190px");
                              
                          }
                          $('.overlay').css({ 'display': 'none' });
                          addScrollToSmallViewBody();

                          $scope.siteId = $stateParams.siteId;
                          coordinator.ClearSubscription("SiteLocationChanged");
                          //*******************OnlineStart*******************************
                       //   onlineProvider.startSite($scope.siteId);
                          //***************************************************
                          $("#splash-page").css("display", "none");
                          //*************************************************
                          $scope.goTo = function (action) {
                              fixLoadingOn(action);
                              switch (action) {
                                  case "PMap":
                                      $state.go('site.preview.map');
                                      break;
                                  case "SList":
                                      $state.go('site.stats.list');
                                      break;
                                  case "settings":
                                      $state.go('site.settings');
                                      break;
                                  case "Reports":
                                      $state.go('site.reports');
                                      break;
                              }
                          }
                          //*************************************************
                          function getSiteName(siteId) {
                              siteProxy.getSiteName(siteId)
                                .success(function (data, status, headers, config) {
                                    $scope.siteName = data.body.siteName;
                                    $scope.projectName = data.body.projectName;
                                    $scope.projectID = data.body.projectID;
                                    mainProvider.CurrentSite.data.level = data.body.sharedView.level;
                                    //*****************************************************************

                                    mainProvider.ExchangeNevigation.data.loginExchangeView = 'Site';
                                    mainProvider.ExchangeNevigation.data.id = $scope.siteId;
                                    mainProvider.ExchangeNevigation.data.type = "";

                                    //***********************************************************
                                    user.saveSharingData(data.body.siteID, data.body.sharedView);
                                    $scope.roleModify = user.getSharingData().sharingData.roleModify;
                                    $scope.startSite = true;
                                })
                                .error(function (data, status, headers, config) {
                                 
                                });
                          }
                          //**************************************************
                          $scope.changeSiteName = function (siteId, siteName) {
                              siteProxy.changeSiteName(siteId, siteName)
                                .success(function (data, status, headers, config) {
                                    mainRouter.callkey("tree", $scope.siteId);
                                    toastr.success("Success");

                                })
                                .error(function (data, status, headers, config) {
                                    toastr.error("Error");
                                });
                          }
                          //*************************************************
                          $scope.DeleteSite= function (siteId) {
                              
                              siteProxy.DeleteSite(siteId)
                                .success(function (data, status, headers, config) {
                                    $scope.exchange();
                                    toastr.success("Success");
                               
                                })
                                .error(function (data, status, headers, config) {

                                });
                          }
                          //***********************************************
                          $scope.exchange = function () {

                              projectProxy.exchange()
                                .success(function (data, status, headers, config) {
                                    data = data.body;
                                    if (data.loginExchangeView == "Device") { //go to device
                                        var postRequest = $.ajax({

                                            type: "GET",
                                            contentType: "application/json",
                                            url: ROOT_ADDR.MF_API + "/Admin/Device/" + data.entry_SN + "/Type",
                                            beforeSend: function (xhr) {
                                                xhr.setRequestHeader("Authorization", 'Bearer ' + data1.accountToken);
                                            },
                                            dataType: "json",
                                            success: function (data2) {
                                                var data2 = data2.body;
                                                $state.go('device.GSI_device.online', { siteId: data.entry_siteID, deviceId: data.entry_SN, typeName: data2.name });
                                                mainRouter.callkey("tree", data.entry_siteID);
                                            },
                                            error: function (data) {

                                            }
                                        });
                                    }
                                    else if (data.loginExchangeView == "Site") {//go to site
                                        LastClickParam1 = data.entry_SiteID;

                                        LastAction = "goToSite";
                                        $state.go('site.preview.map', { siteId: data.entry_SiteID });
                                        mainRouter.callkey("tree", data.entry_siteID);
                                    }

                                    else if (data.loginExchangeView == "Welcome") { //go to welcome
                                        $state.go('welcome');
                                        
                                    }
                                    else if (data.loginExchangeView == "Project") { //go to welcome
                                        $state.go('site.preview.map', { siteId: data.entry_ProjectID });
                                        mainRouter.callkey("tree", data.entry_ProjectID);
                                    }







                                   

                                })
                                .error(function (data, status, headers, config) {

                                });
                          }
                          //***********************************************
                          $scope.goToParentProject = function (id) {
                              $state.go('site.preview.map', { siteId: id });
                              mainRouter.callkey("tree", id);
                          }

                          //**************************************************
                          if ($(".navbar-content").css("display") == 'none') {
                              openNavbar();
                          }
                         
                          getSiteName($scope.siteId);

                  }]
              }
              ,
              'navbar@': {
                  template: '<div navbar-directive atr="menu"></div>',
              }
          }
      })

}]);