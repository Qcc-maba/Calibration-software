
(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.accessories', []);

})(angular);
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
angular.module("module.device", [
     "ui.router"
 ])
.config(['$stateProvider', function ($stateProvider) {
    $stateProvider
    .state('device', {
        url: '/device/:deviceId',
        views: {
            'root@': {
                templateUrl: 'app/modules/module.device/device.html',
                controller: ['$scope', '$stateParams', '$state', 'siteProxy', '$filter', 'mainProvider', 'user', 'mainRouter', function ($scope, $stateParams, $state, siteProxy, $filter, mainProvider, user, mainRouter) {
                    $('#dragbar').css("display", "none");

                   
                    //*******************************************************
                    siteProxy.GetDeviceInfo($stateParams.deviceId)
                        .success(function (data) {
                            $scope.device = data.body;
                            user.saveSharingData(-1, data.body.sharedView);
                           $scope.privilige = user.getSharingData().sharingData;
                            $scope.deviceIndex = findCurrentDeviceIndexInArray($scope.device.deviceListView);
                        }).error(function (data, status, headers, config) {
                            toastr.error($filter('translate')('toastrErrMsgGet'));
                        });
                    //************************************************************
                    findCurrentDeviceIndexInArray = function (list) {
                        for (var i = 0; i < list.length; i++) {
                            if (list[i].sn == $stateParams.deviceId) {
                                mainProvider.CurrentDevice.data = list[i];
                                $scope.currentDevice = list[i];
                                if (i == 0) {
                                    $scope.nextPrev = {
                                        nextShow: true,
                                        prevShow: false
                                    }
                                }
                                else if (i == list.length-1) {
                                    $scope.nextPrev = {
                                        nextShow: false,
                                        prevShow: true
                                    }
                                }
                                else {
                                    $scope.nextPrev = {
                                        nextShow: true,
                                        prevShow: true
                                    }
                                }
                                return i;
                            }
                        }
                        return null
                    }


                    $scope.prev = function () {
                        if ($scope.deviceIndex > 0) {
                            $state.go('device.XCI_device.online', { deviceId: $scope.device.deviceListView[$scope.deviceIndex - 1].sn});
                        } else {
                            
                        }
                    }
                    $scope.next = function () {
                        if ($scope.deviceIndex < $scope.device.deviceListView.length-1) {
                            $state.go('device.XCI_device.online', { deviceId: $scope.device.deviceListView[$scope.deviceIndex + 1].sn});
                        }
                    }


                    $scope.goToSite = function (id) {
                        
                        $state.go('site.preview.map', { siteId: id });
                        mainRouter.callkey("tree", id);
                    }


                    $("#splash-page").css("display", "none");

                    closeNavbar();
                }
                ]
            }
        }
    })
   

}]);
(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.filters', []);

})(angular);

(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.httpProxies', ['module.translate']);

})(angular);
(function (angular) {
    'use strict';


    var mi = angular.module('module.main', []);

})(angular);
(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.message', []);

})(angular);
(function (angular) {
    mi = angular
        .module('module.menuNavigation', []);
})(angular);






angular.module("module.project",
    [     "module.site"
          ,"ui.router"
       
    ])
.config(['$stateProvider', function ($stateProvider) {
    $stateProvider
    .state('project', {
        url: '/project/:projectId',
        views: {
            'root@': {
                templateUrl: 'app/modules/module.project/project.html',
                controller: ['$scope', '$stateParams', 'projectProxy', '$state', function ($scope, $stateParams, projectProxy, $state) {
                    $scope.projectId = $stateParams.projectId;
                    $scope.ladda = {
                        "deleteProject": false
                    };
                    //**********************changeProjectName********************************************************
                    $scope.changeProjectName = function (projectId, projectName) {

                        projectProxy.changeProjectName(projectId, projectName) //no service
                           .success(function (data, status, headers, config) {
                               var obj = {};
                               obj.projectID = $scope.projectId;
                               obj.projectName = $scope.projectName;
                               $rootScope.$broadcast('projectChangeName', obj);
                               toastr.success("Success");
                           })
                           .error(function (data, status, headers, config) {
                               toastr.error("Error");
                           });
                    }
                    //***********************getProjectName*******************************************************
                    function getProjectName(id) {
                        projectProxy.getProjectName(id) //no service
                            .success(function (data, status, headers, config) {
                                $scope.projectName = data.name;
                            })
                            .error(function (data, status, headers, config) {
                         
                            });
                    }
                    //************************goTo*****************************************************
                    $scope.goTo = function (action) {
                             
                        fixLoadingOn(action);
                        switch (action) {
                            case "PMap":
                                $state.go('project.map');
                                break;
                            case "PSettings":
                                $state.go('project.settings');
                            
                        }
                    }
                    //****************************DeleteProject*******************************************
                    $scope.DeleteProject = function (projectId) {
                       
                        projectProxy.DeleteProject(projectId)
                            .success(function (data, status, headers, config) {
                                //@@@@@@ event that go to navbar and delete current project from tree
                            })
                            .error(function (data, status, headers, config) {

                            });
                    }

                    openNavbar();
                    getProjectName($scope.projectId);
                   $("#splash-page").css("display", "none");
                }
           ]}
        }
    })
    .state('project.map', {
        url: '/map',
        template: '<div project-map ng-model="projectId"></div>'
    })
     .state('project.settings', {
         url: '/settings',
         template: '<div project-settings ng-model="projectId"></div>'

     })
    
}]);

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
                          if ($(window).width() > SMALL_VIEW) {
                              $('#dragbar').css("display", "block");
                              $('.tree').css("width", '225px');
                              $('#dragbar').css("marginLeft", '225px');
                              $('.main-content').css("marginLeft", '225px');
                              $('.navigation-toggler').css("marginLeft", "190px");
                           }
                          

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
(function (angular) {
	'use strict';

	//////////////// AngularJS //////////////
	angular.module('module.support', ["ui.router"])
		.config(['$stateProvider', '$urlRouterProvider',function ($stateProvider, $urlRouterProvider) {
		$stateProvider
		  .state('support', {
		  	url: '/support',
		  	views: {
		  		'root@': {
		  			template: '<div support></div>',
		  			controller: function () {

		  				$("#splash-page").css("display", "none");
		  			}
		  		}

		  	}
		  })

	}]);

})(angular);






(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.support')
        .directive('support', supportFactory);



    function supportFactory() {
        return {
            restrict: 'EA',

            templateUrl: 'app/modules/module.support/support.html',

            controller: ['$scope', function ($scope) {

                $scope.laddaMsg = false;
               
                $scope.messages = [{ t: 1, s: [{ q: 1, a: 1 }, { q: 2, a: 2 }, { q: 3, a: 3 }, { q: 4, a: 4 }, { q: 5, a: 5 } ] },
                                   { t: 2, s: [{ q: 1, a: 1 }, { q: 2, a: 2 }, { q: 3, a: 3 }, { q: 4, a: 4 }, { q: 5, a: 5 }] },
                                   { t: 3, s: [{ q: 1, a: 1 }, { q: 2, a: 2 }, { q: 3, a: 3 }, { q: 4, a: 4 }, { q: 5, a: 5 }] }];
                $scope.windowWidth = window.outerWidth;

                window.onresize = function (event) {
                    $scope.windowWidth = window.outerWidth;
                    $scope.$apply();
                };

                $scope.saveMessage = function (func) {
                    $scope.laddaAlerts = true;
                    //send to service
                    $scope.laddaMsg = false;
                    func();
                }
                $scope.goToProfile = function () {
                    window.open(MAIN_LINKS.PROFILE.link, '_blank');
                }

             
            }],
            link: function (scope, element, attrs, ngModel) {



            }




        };

    }
})(angular);
(function(angular){
    var translate = angular.module("module.translate", [])
})(angular);

   
(function (angular) {
    'use strict';


    var mi = angular.module('module.weather.forecast', []);

})(angular);

angular.module("module.welcome",
    [
          "ui.router"

    ])
.config(['$stateProvider', '$urlRouterProvider', function ($stateProvider, $urlRouterProvider) {

    $urlRouterProvider


    $stateProvider
      .state('welcome', {
          url: '/welcome',
          views: {
              'root@': {
                  templateUrl: 'app/modules/module.welcome/welcome.html',
                  controller: ['$scope', '$stateParams', '$state',
                      function ($scope, $stateParams, $state) {
                          $scope.removAarrow = function () {
                             
                              $scope.openModal = true
                              $("#arrow").css("display", "none");
                          }
                          $("#splash-page").css("display", "none");
                          closeNavbar();
                       
                      }]
              }
              //'navbar@': {
              //    templateUrl: 'app/modules/module.navbar/navbar.html',
              //}


          }
      })

     



}]);

(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.widgets', []);

})(angular);
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
angular.module("module.XCI.Device", [
     "ui.router"
    , "module.widgets"
    , "colorpicker.module"
    ,"module.httpProxies"])
.config(['$stateProvider',function ($stateProvider) {
    $stateProvider
    .state('device.XCI_device', {
        url: '',
        views: {
            '': {
                templateUrl: 'app/modules.devices/XCI.Device/XCI.device.html',
                controller: ['$scope', '$stateParams', '$state', 'user', 'onlineProvider', function ($scope, $stateParams, $state, user, onlineProvider) {
                    $scope.deviceId = $stateParams.deviceId;
                    $scope.siteId = $stateParams.siteId;
                    $scope.projectId = $stateParams.projectId;

                    $scope.privilige = user.getSharingData().sharingData.roleModify;
                    $("#splash-page").css("display", "none");

                    //*******************OnlineStart*******************************
                  //  onlineProvider.startDevice($scope.deviceId);
                    //*************************goTo************************
                    $scope.goTo = function (action , param1) {

                        fixLoadingOn(action, param1);
                        switch (action) {
                            case "DView":
                                $state.go('device.XCI_device.view');
                                break;
                            case "DOnline":
                                $state.go('device.XCI_device.online');
                                break;
                        }
                    }
                    //*************************************************
                    $scope.DeleteDevice = function(deviceId) {
                        //missing service
                        //siteProxy.DeleteDevice(deviceId)
                        //  .success(function (data, status, headers, config) {

                        //  })
                        //  .error(function (data, status, headers, config) {

                        //  });
                    }
                }
            ]}
        }
    })
   .state('device.XCI_device.view', {
       url: '/view',
       views: {
           '': {
               template: '<div device-view ng-model="deviceId"></div>',
               controller: ['$scope', '$stateParams', function ($scope, $stateParams) {
                   $scope.deviceId = $stateParams.deviceId;
                   $scope.siteId = $stateParams.siteId;
                   $scope.projectId = $stateParams.projectId;
               }
           ]}
       }
   })
   .state('device.XCI_device.online', {
       url: '/online',
       views: {
           '': {
               template: '<div online-directive></div>',
               controller: ['$scope', '$stateParams', function ($scope, $stateParams) {
                   $scope.deviceId = $stateParams.deviceId;
                   $scope.siteId = $stateParams.siteId;
                   $scope.type = $stateParams.typeName;
                   //$scope.gpmValue = 444;
                   //$scope.mAValue = 124.5;

                   $("#splash-page").css("display", "none");
               }
           ]}
       }
   })
   
        .state('device.XCI_device.stats', {
        url: '/stats',
        templateUrl: 'app/modules/module.stats/stats.html'
    })

}]);

(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.accessories')
        .provider('coordinator', coordinator);


    //////////////// JavaScript //////////////

    function coordinator() {

        var bus = [];

        function seachForBus(busName) {
            for (var i = 0; i < bus.length; i++) {
                if (bus[i].busName == busName) {
                    return bus[i];
                }
            }

            var newBus = {
                busName: busName,
                subscribers: []
            };

            bus.push(newBus);

            return newBus;
        }

        function ClearSubscription(eventName) {

            var bus = seachForBus(eventName);
            bus.subscribers = [];
        }

        function SubscribeEvent(eventName, callback) {

            var bus = seachForBus(eventName);
            bus.subscribers.push(callback);
        }
      
        function PublishEvent(eventName, obj) {
            var event = {
                eventName: eventName,
                data: obj                
            };

            var bus = seachForBus(eventName);

            for (var i = 0; i < bus.subscribers.length; i++) {
                bus.subscribers[i](event);
            }
        }

        return {
            $get: ['$http', 'baseProxy', function ($http, baseProxy) {

   

                //interface
                return {
                    PublishEvent: PublishEvent,
                    SubscribeEvent: SubscribeEvent,
                    ClearSubscription: ClearSubscription
                };
            }]
        }
    }
})(angular);

(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.accessories')
        .provider('directiveComm', directiveCommFactory);


    //////////////// JavaScript //////////////
    function directiveCommFactory() {

        function Connector() {

        }

        Connector.prototype.lastArguments_Up = null;
        Connector.prototype.lastArguments_Down = null;

        Connector.prototype.CallbackUp = function () {
            this.lastArguments_Up = arguments;

            if (this._CallbackUp) {
                return this._CallbackUp.apply(this, this.lastArguments_Up);
            }
        }
        Connector.prototype.CallbackDown = function () {

            this.lastArguments_Down = arguments;

            if (this._CallbackDown) {
                return this._CallbackDown.apply(this, this.lastArguments_Down);
            }

        }
        Connector.prototype.SetCallbackUp = function (callback) {
            this._CallbackUp = callback;

            if (this.lastArguments_Up) {
                return callback.apply(this, this.lastArguments_Up);
            }
        }
        Connector.prototype.SetCallbackDown = function (callback) {
            this._CallbackDown = callback;

            if (this.lastArguments_Down) {
                return callback.apply(this, this.lastArguments_Down);
            }
        }


        function _CreateConnector() {

            return new Connector();
        }


        return {
            $get: ['$http', 'baseProxy', function ($http, baseProxy) {



                //interface
                return {
                    CreateConnector: _CreateConnector
                };
            }]
        }
    }
})(angular);

(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    allAlertsFactory.$inject = ['$log'];
    angular.module('module.allAlerts')
        .directive('allAlerts', allAlertsFactory);



    function allAlertsFactory($log) {
        return {
            restrict: 'EA',
            
            templateUrl: 'app/modules/module.alert/allAlert.html',

            controller: ['$scope', 'projectProxy', 'mainRouter', 'profileProxy', 'directiveComm', function ($scope, projectProxy, mainRouter, profileProxy, directiveComm) {
                
                $scope.connector = directiveComm.CreateConnector();
                $scope.includeSub = false;
                $scope.currentPage = 1;
                var PageSize = 10;
                $scope.pagerFlag = false;
                
                //*********************************************************
                mainRouter.register("treeAlertForSiteID", function (data) {
                    $scope.projectNumber = data;
                    $scope.getAlerts();
                   
                });
               
                //*************************************************************
                $scope.macroAlerts = function (param) {
                    param == 0 ? param = true : param = false;
                    projectProxy.macroAlerts($scope.projectNumber, $scope.includeSub, param)
                                      .success(function (data) {
                                          
                                      });
                }
                //***************************************************************
                $scope.deviceAlertChange = function (element) {
                    element.isChange = true;
                    $scope.showSave = true;
                }
                //************************************************************
                $scope.postAlertsTableData = function () {
                    projectProxy.postAlertsTableData($scope.projectNumber, $scope.tableData)
                                      .success(function (data) {

                                      });
                }
                //*************************************************************
                $scope.getAlerts = function() {
                    projectProxy.getProjectAlerts($scope.projectNumber, $scope.includeSub, $scope.currentPage, PageSize)
                                       .success(function (data) {
                                           $scope.tableData = data.body;
                                           if ($scope.tableData.siteAlertsView.length + 1 > PageSize) {
                                               $scope.pagerFlag = true;
                                               $scope.connector.CallbackDown($scope.currentPage, PageSize, $scope.tableData.totalItems);
                                           }
                                           
                                       });
                }
                //************************************************************
                $scope.connector.SetCallbackUp(function (pageNumber) {
                    $scope.currentPage = pageNumber;
                    $scope.getAlerts();
                });

                $("#splash-page").css("display", "none");

                closeNavbar();

            }],
            link: function (scope, element, attrs, ngModel) {

              

            }




        };

    }
})(angular);

(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.device')
        .directive('addCtrl', addCtrlDFactory);
    /*********************************************************************************************************************************************************************/
    function addCtrlDFactory() {
        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.device/addDevice/addCtrl.html',
            controller: ['$scope', '$window', '$stateParams', '$state', 'baseProxy', 'deviceProxy', 'zoneProxy', 'directiveComm', function ($scope, $window, $stateParams, $state, baseProxy, deviceProxy, zoneProxy, directiveComm) {
                //*************************************************Attributs******************************
                $scope.siteId = $stateParams.siteId;
                //**************************************
                $scope.setZonesDefinition = true;
                $scope.rate = 15;
                //**************************************
                $scope.nextDisable = true;
                $scope.finish = true;
                $scope.step = 0;
                $scope.ladda = {
                    SaveNewCtrl: false,
                    SetZonesAdviser:false,
                    next: false,
                    prev: false,
                    go: false,
                    acceptSeggestion: false
                };
                $scope.ctrlDetails = {'siteID': $scope.siteId, 'deviceName': '', 'serialNumber': '', 'verificationCode': '','zones':[] };
                $scope.adviserConnector = directiveComm.CreateConnector();
                //***********************************************************Function**********************

                //************************************************SetCallbackUp(scheduleConnector)******************************
                $scope.adviserConnector.SetCallbackUp(function (obj) {
                   
                    var promise = {
                        callback: null,
                        success: function (callback) {
                            this.callback = callback;
                        }

                    };
                    if (obj.service == "AcceptSuggestions") {

                        $scope.ctrlDetails.zones[$scope.zoneIndex].acceptSuggestions = true;

                        promise.callback();

                    } 
                    return promise;

                });
                //***********************************************************on(deviceGeoLocation)**********************
                $scope.$on('deviceGeoLocation', function (event, data) {
                    $scope.ctrlLoc = data;
                });
                //***********************************************************next(Outer)**********************
                $scope.next = function () {
                    switch ($scope.step) {
                        case 0:
                            if ($scope.addDeviceForm.$valid) {
                                $scope.finish = true;
                                $scope.step++;
                                $scope.setStep($scope.step ,1);
                                $scope.notValid = false;
                                $scope.nextDisable = false;
                            }
                            else {
                                $scope.notValid = true;
                            }
                            break;
                        case 1:
                            $scope.step++;
                            $scope.setStep($scope.step, 1);
                            $scope.nextDisable = true;
                            break;
                        case 2:
                            $scope.finish = true;
                            $scope.zoneIndex = 0;
                            $scope.ctrlDetails.location = baseProxy.buildPinLocation($scope.ctrlLoc.lat, $scope.ctrlLoc.lan);
                            //@@@@@need to build service
                            zoneProxy.getZoneSaggestionWizard('0000000000002246', 2)
                               .success(function (data) {
                                   var suggestions = {
                                       isAccepted : false,
                                       suggestion_TotalWeeklyMinutes: 180,
                                       suggestion_TotalWeeklyDays:3,
                                       suggestion_MaximumCycleMinutes:30,
                                       suggestion_SoakTimeMinutes: 10,
                                   }
                                   buildingZones(data.body, suggestions);
                                   var currentZone = {
                                       categories: $scope.ctrlDetails.zones[$scope.zoneIndex].categories,
                                       suggestions: $scope.ctrlDetails.zones[$scope.zoneIndex].suggestions
                                   }
                                   $scope.adviserConnector.CallbackDown(currentZone);
                            });
                            $scope.step++;
                            $scope.setStep($scope.step, 1);
                            $scope.nextDisable = true;
                            break;
                        case 3:
                                $scope.finish = true;
                                $scope.step++;
                                $scope.setStep($scope.step, 1);
                                $scope.nextDisable = true;
                            break;

                        case 4:
                            $scope.finish = false;
                            break;

                    }
                }
                //***********************************************************nextZone(Outer)************************
                $scope.nextZone = function () {
                    if ($scope.zoneIndex < $scope.ctrlDetails.zonesAvailable) {
                        $scope.finishSetZone = false;
                        $scope.zoneIndex++;
                        var currentZone = {
                            categories: $scope.ctrlDetails.zones[$scope.zoneIndex].categories,
                            suggestions: $scope.ctrlDetails.zones[$scope.zoneIndex].suggestions
                        }
                        $scope.adviserConnector.CallbackDown(currentZone);
                    }
                }
                //***********************************************************prevZone(Outer)************************
                $scope.prevZone = function () {
                    if ($scope.zoneIndex > 0) {
                        $scope.finishSetZone = false;
                        $scope.zoneIndex--;
                        var currentZone = {
                            categories: $scope.ctrlDetails.zones[$scope.zoneIndex].categories,
                            suggestions: $scope.ctrlDetails.zones[$scope.zoneIndex].suggestions
                        }
                        $scope.adviserConnector.CallbackDown(currentZone);
                    }
                }
              
                //***********************************************************prev(Outer)**********************
                $scope.prev = function () {
                    switch ($scope.step) {
                        case 0:
                            $scope.nextDisable = true;
                            break;
                        case 1:
                            $scope.finish = true;
                            $scope.step--;
                            $scope.setStep($scope.step, 2);
                            $scope.nextDisable = true;
                            break;
                        case 2:
                            $scope.finish = true;
                            $scope.step--;
                            $scope.setStep($scope.step, 2);
                            $scope.nextDisable = true;
                            break;
                        case 3:
                            $scope.finish = true;
                            $scope.step--;
                            $scope.setStep($scope.step, 2);
                            $scope.nextDisable = true;
                            break;
                        case 4:
                            $scope.finish = false;
                            $scope.step--;
                            $scope.setStep($scope.step, 2);
                            $scope.nextDisable = true;
                            break;
                    }
                }
                //***********************************************************setStep(Outer)**********************
                $scope.setStep = function (step,param) {
                    switch (step) {
                        case 0:
                            $scope.first = 'active';
                            $scope.second = 'next';
                            $scope.third = 'next';
                            $scope.fourth = 'next';
                            $scope.five = 'next'
                            $scope.step = step;
                            break;
                        case 1:
                            $scope.first = 'previous visited';
                            $scope.second = 'active';
                            $scope.third = 'next';
                            $scope.fourth = 'next';
                            $scope.five = 'next'
                            $scope.step = step;
                            break;
                        case 2:  
                            $scope.first = 'previous visited';
                            $scope.second = 'previous visited';
                            $scope.third = 'active';
                            $scope.fourth = 'next';
                            $scope.five = 'next'
                            $scope.step = step;
                            break;
                        case 3:
                            $scope.first = 'previous visited';
                            $scope.second = 'previous visited';
                            $scope.third = 'previous visited';
                            $scope.fourth = 'active';
                            $scope.five = 'next'
                            $scope.step = step;
                            break;
                        case 4:
                            $scope.first = 'previous visited';
                            $scope.second = 'previous visited';
                            $scope.third = 'previous visited';
                            $scope.fourth = 'previous visited';
                            $scope.five = 'active';
                            $scope.step = step;
                            break;
                    }
                    if (param == 1) {
                        $scope.ladda.next = false;
                    }
                    else {
                        $scope.ladda.prev = false;
                    }
                    

                }
                //***********************************************************SaveNewDevice(Outer)**********************
                $scope.SaveNewDevice = function (param) {
                    $scope.ladda.SaveNewCtrl = true;
                    $scope.ctrlDetails.zones= $scope.ctrlDetails.zones.slice(0, $scope.ctrlDetails.zonesAvailable);
                    deviceProxy.NewCtrlSave($scope.ctrlDetails.serialNumber, $scope.ctrlDetails)
                    .success(function (data, status, headers, config) {
                        $scope.DeviceId = data.body.createdDevice.sn;
                        $scope.step = 0;
                        $scope.setStep(0);
                        $scope.ctrlDetails = { 'siteID': '', 'deviceName': '', 'serialNumber': '', 'verificationCode': '','zones':[] };
                        toastr.success('New controller add', 'success!');
                    
                        $scope.ladda.SaveNewCtrl = false;
                        var projectId= $stateParams.projectId ||376;
                        var siteId= $stateParams.siteId ||377;
                        $state.go('device.XCI_device.online', { projectId: projectId, siteId: siteId, deviceId: data.body.createdDevice.sn, typeName: "XCI-WIFI" });
                       // 
                    }).error(function (data, status, headers, config) {

                    });
                }
                //************************************************************buildingZones*****************************
                function buildingZones(categories, irrigationSuggestions) {
                  var oneZone = {
                        zoneName: "",
                        zoneId: 0,
                        acceptSuggestions:false,
                        plantType: {
                            selected: {},
                            restType: {}
                        },
                        slopeType: {
                            selected: {},
                            restType: {}
                        },
                        soilType: {
                            selected: {},
                            restType: {}
                        },
                        sprinklerType: {
                            selected: {},
                            restType: {}
                        },
                        sunExposureType: {
                            selected: {},
                            restType: {}
                        }

                    }
                  for (var key1 in categories) {
                      if (categories.hasOwnProperty(key1)) {
                          var Type = categories[key1];
                            if (Type.optionalValues) {
                               oneZone[key1].restType = jQuery.extend(true, {}, Type.optionalValues);
                                for (var i = 0; i < Type.optionalValues.length; i++) {
                                    if (Type.optionalValues[i].isSelected) {
                                       oneZone[key1].selected = jQuery.extend(true, {}, Type.optionalValues[i]);

                                        break;
                                    }
                                }
                            }
                        }
                    }


                  for (var i = 0 ; i < $scope.ctrlDetails.zonesAvailable; i++) {
                      var newOb={};
                        newOb.categories = jQuery.extend(true, {},oneZone);
                        newOb.zoneId = i;
                       
                        newOb.zoneName = "Zone " + i;
                        newOb.suggestions = jQuery.extend(true, {}, irrigationSuggestions);
                       
                        $scope.ctrlDetails.zones.push(newOb);
                    }
                    $scope.finishParse = true;
                }
                //***********************************************************SaveNewDevice(Outer)**********************
                $scope.closeModal =function(){
                    $scope.step = 0;
                    $scope.setStep(0);
                    $scope.ctrlDetails = { 'siteID': '', 'deviceName': '', 'serialNumber': '0000000000000001', 'verificationCode': '' };
                }
                //***********************************************************chooseSiteName(Outer)**********************
                $scope.chooseSiteName = function (index) {
                    $scope.site = $scope.sites[index].siteId;

                }
                //***********************************************************getZonesNumber(Outer)**********************
                $scope.getZonesNumber = function (index) {
                    $scope.ctrlDetails.zonesAvailable = $scope.zonesNum[index];
                    $scope.zoneIndex = 0;
                    
                    

                }

                //***********************************************************varify(outer)***********************************
                $scope.varify = function () {
                    if ($scope.addDeviceForm.$valid) {
                        $scope.ladda.go = true;
                        deviceProxy.SnValidation($scope.ctrlDetails.serialNumber, $scope.ctrlDetails.verificationCode)
                               .success(function (data, status, headers, config) {
                                   //build zone list for step 3
                                   $scope.ctrlDetails.zonesAvailable = data.body.maxZonesAvailable;
                                   $scope.ctrlDetails.zonesAvailable = 16;
                                   $scope.zonesNum = [];
                                   var i = 2;
                                   while (i < $scope.ctrlDetails.zonesAvailable) {
                                       $scope.zonesNum.push(i);
                                       i += 2;
                                   }
                                   $scope.zonesNum.push($scope.ctrlDetails.zonesAvailable);
                                   $scope.finish = true;
                                   $scope.ladda.go = false;
                                   //wifi or regular
                                   //@@@@@@@
                                   data.body.type = "wifi";
                                   if (data.body.type == "wifi") {
                                       $scope.wifi = true;
                                   }

                                   else {
                                       $scope.nextDisable = true;
                                   }
                                  
                               }).error(function (data, status, headers, config) {
                                   toastr.error('Serial number is ' + data, 'Error!'); //not exists or use
                               });
                        $scope.notValid = false;
                    }
                    else {
                        $scope.notValid = true;
                    }
                }
                //***********************************************************goToNetwork(outer)***********************************
                //@@@@@
                $scope.goToNetwork = function () {
                    
                    $window.open(ROOT_ADDR.SYSTEM_MF_ROOT + '/cyberRainWifi.html');
                }
                $scope.setStep($scope.step);
            }
        ]};
    }

    /*******************************************************************************************************************************************************************************/

})(angular);







(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.device')
        .directive('gmapDevice', gmapDeviceFactory);

    /************************************************************************************************************************************************************************/
    function gmapDeviceFactory() {

        return {
            restrict: 'A',
            transclude: true,
            template: '<div id="map-canvas" style="height: 300px"></div> ',
            replace: true,
            controller:['$scope', function ($scope) {
             //**************************************createMap(Outer)*******************
            }],
            link: function (scope, element, attrs) {

                //*************************************Attributs*******************************
                scope.UseAutoBounds;
                var controlUI;
                var AutoUI;
                var latlngbounds;
                var map;
                //**************************************Functions********************************
                //**************************************$on(addDeviceMapEvent)*******************
                scope.$on('addDeviceMapEvent', function (event, data) {
                    
                    createMap(data);

                });
                //**************************************createMap(Inner)*******************
                function createMap (data) {
                    var geocoder = geocoder = new google.maps.Geocoder();
                    var markers = [];
                        var obj = {};
                        obj.lat = data.mapData.lat;
                        obj.lng = data.mapData.lan;
                        markers.push(obj);
                    var mapOptions = {
                        center: new google.maps.LatLng(data.mapData.lat, data.mapData.lan),
                        zoom: 8,
                        mapTypeId: google.maps.MapTypeId.ROADMAP
                    };
     
                   var map = new google.maps.Map(element[0], mapOptions);
                    for (var i = 0; i < markers.length; i++) {
                        var data = markers[i]
                        var myLatlng = new google.maps.LatLng(data.lat, data.lng);
                        var marker = new google.maps.Marker({
                            position: myLatlng,
                            map: map,
                            draggable: true,
                            animation: google.maps.Animation.DROP,
                            icon: 'https://maps.google.com/mapfiles/ms/icons/green-dot.png'
                        });
                        (function (marker, data) {
                            google.maps.event.addListener(marker, "dragend", function (e) {
                                var lat, lng, address;
                                geocoder.geocode({ 'latLng': marker.getPosition() }, function (results, status) {
                                    if (status == google.maps.GeocoderStatus.OK) {
                                        var obj = {};
                                        obj.lat = marker.getPosition().lat();
                                        obj.lan = marker.getPosition().lng();
                                        scope.$emit('deviceGeoLocation', obj);
                                    }
                                });
                            });
                        })(marker, data);
                        
                    }

                }
                
            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);

(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.device')
        .directive('googleplace', googleplaceFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function googleplaceFactory() {
        return {
            restrict: 'EA',
            controller:['$scope','$filter','deviceProxy', function ($scope, $filter, deviceProxy) {
                //******************************Attributs****************************************
                $scope.observes = true;

                //*****************************Function******************************************
                //*****************************showPosition(Inner)******************************************
                function showPosition (position) {
                    var obj = {};
                    obj.lat = position.coords.latitude;
                    obj.lan = position.coords.longitude;
                    $scope.$broadcast('addDeviceMapEvent', { mapData: obj });
                    $scope.$emit('deviceGeoLocation', obj);
                }
                //*****************************getLocation(Outer)******************************************
                $scope.getLocation = function () {
                    if (navigator.geolocation) {
                        navigator.geolocation.getCurrentPosition(showPosition);
                    } else {
                        toastr.error($filter('translate')('toastrErrMsgGet'));
                        //California, United States
                        obj.lat = 36.542750;
                        obj.lan = -119.800532;
                        $scope.$broadcast('addDeviceMapEvent', { mapData: obj });
                        $scope.$emit('deviceGeoLocation', obj);
                    }
                }
                //*****************************chooseLocation(Outer)******************************************
                $scope.chooseLocation = function (add) {
                    if(add!=''){
                    $scope.add = add;
                    $scope.ctrlLocation = add;
                    deviceProxy.GetCoordinate(add)
                   .success(function (data) {
                       var obj = {};
                       obj.lat = data.results[0].geometry.location.lat;
                       obj.lan = data.results[0].geometry.location.lng;
                       $scope.$broadcast('addDeviceMapEvent', { mapData: obj });
                       $scope.$emit('deviceGeoLocation', obj);
                   });
                    }
                }
            }],
            link: function (scope, element, attrs) {
            
                var autocomplete = new google.maps.places.Autocomplete(element[0], { types: ['geocode'] });
                var options = {
                    types: [],

                };
                scope.getLocation();
                element.blur(function (e) {
                    window.setTimeout(function () {
                        angular.element(element).trigger('input');
                        scope.chooseLocation(element[0].value);
                    }, 0);
                });
            }
        }
    }
})(angular);







(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.device')
        .directive('adviserDirective', adviserDirectiveFactory);
    /***********************************************************************************************************************************************************************/
    function adviserDirectiveFactory() {
        return {
            restrict: 'EA',
            scope: {
                comm: '=' 
            },
            templateUrl: 'app/modules/module.device/adviser/adviser.html',

            controller: ['$scope', 'zoneProxy', '$stateParams', 'mainRouter', function ($scope, zoneProxy, $stateParams, mainRouter) {
                $scope.deviceId = $stateParams.deviceId;
                $scope.zoneId = $stateParams.zoneId;
                $scope.hideRecLink = true;
                //**************************************Attribute******************************
                
                $scope.ladda = {
                    "acceptSeggestion": false,
                    "plantType": false,
                    "sprinklerType":false,
                    "slopeType":false,
                    "soilType":false,
                    "sunExposureType": false 
                }
           
                //***************************************Functions******************************
                //************************************************SetCallbackUp(scheduleConnector)******************************
                $scope.comm.SetCallbackDown(function (obj) {
                    $scope.adviser = {
                        categories : obj.categories,
                        suggestions: {},
                        current:{
                           
                        }
                    }

                    showRecomendation();
                  
                });

                
                mainRouter.register("showRecomendationEvent", function (data) {
                    showRecomendation();
                });

                var showRecomendation = function () {
                    zoneProxy.getIrrigationSuggestion($scope.deviceId, $scope.zoneId)
                             .success(function (data) {
                                 data = data.body;
                                 $scope.adviser.suggestions.suggestion_TotalWeeklyMinutes = data.suggestion_TotalWeeklyMinutes;
                                 $scope.adviser.suggestions.suggestion_TotalWeeklyDays = data.suggestion_TotalWeeklyDays;
                                 $scope.adviser.suggestions.suggestion_MaximumCycleMinutes = data.suggestion_MaximumCycleMinutes;
                                 $scope.adviser.suggestions.suggestion_SoakTimeMinutes = data.suggestion_SoakTimeMinutes;

                                 //**************************************
                                 if (data.scheduleType=='Weekly') {
                                     $scope.tableType = 'Weekly';
                                    
                                 }
                                 $scope.adviser.current.current_TotalWeeklyMinutes = data.current_TotalWeeklyMinutes;
                                 $scope.adviser.current.current_WateringDays = data.current_WateringDays;
                                 $scope.adviser.current.maxCycleTime = data.maxCycleTime;
                                 $scope.adviser.current.maxSoakTime = data.maxSoakTime;
                            
                                
                             });

                }
              
                //***********************************************************AcceptSuggestions(Outer)***********************************
                $scope.AcceptSuggestions = function () {
                    $scope.showHideRecommendation = false;
                    $scope.ladda.acceptSeggestion = true;
                    zoneProxy.acceptSuggestions($scope.deviceId, $scope.zoneId)
                            .success(function (data) {
                                data = data.body;
                                mainRouter.callkey("refreshZonePage", {});
                                $scope.closeAdviser();
                                toastr.success('changes saves', 'success!');
                                $scope.ladda.acceptSeggestion = false;

                            });
                }
                //**********************************************************changeSelected(Outer)***************************************
                $scope.changeSelected = function (type, newSelected) {
                    //@@@@@
                    //send to server and get sugesstion from service?????????????
                    
                   
                    ///**************sucsses*******************************
                    $scope.adviser.suggestions.isAccepted = false;
                    $scope.adviser.categories[type].selected = newSelected;
                    $scope.adviser.service = "changeSelected";
                    $scope.ladda[type] = true;
                    $scope.ladda[type] = false;
                    
                }
                //*********************************************************************************************
                $scope.closeAdviser = function () {
                    $('.adviserBigImgFrame').css("display", "none");
                }
                //*********************************************************************************************
                $scope.openAdviser = function () {
                    $('.adviserBigImgFrame').css("display", "block");
                }
              //*********************************************************************************************
                $scope.getSelectedType = function (Type , number) {
                    $scope.choosenType = $scope.adviser.categories[Type];
                    $scope.choosenTypeNumber = number;
                    $scope.openAdviser();
                }
                //*********************************************************************************************
                $scope.getSelectedSubType = function (subTypeSelected) {
                    $scope.choosenType.selected = subTypeSelected;
                    $scope.saveAndGetRecommendation();
                }
                //*********************************************************************************************
                //$scope.blinkingDivOpen = function () {
                //    $("#blinkingDiv").css( "display","block" );
                //}
                ////*********************************************************************************************
                //$scope.blinkingDivClose = function () {
                //    $("#blinkingDiv").css("display", "none");
                //}
                //*********************************************************************************************
                $scope.saveAndGetRecommendation = function () {
               
                    var types = [];
                    types.push({
                        typeID: $scope.adviser.categories.plantType.advisorTypeID,
                        subTypeID: $scope.adviser.categories.plantType.selected.typeID,
                        customValue: $scope.adviser.categories.plantType.selected.isCustom ? $scope.adviser.categories.plantType.selected.value : null
                    });
                    types.push({
                        typeID: $scope.adviser.categories.slopeType.advisorTypeID,
                        subTypeID: $scope.adviser.categories.slopeType.selected.typeID,
                        customValue: $scope.adviser.categories.slopeType.selected.isCustom ? $scope.adviser.categories.slopeType.selected.value : null
                    });
                    types.push({
                        typeID: $scope.adviser.categories.soilType.advisorTypeID,
                        subTypeID: $scope.adviser.categories.soilType.selected.typeID,
                        customValue: $scope.adviser.categories.soilType.selected.isCustom ? $scope.adviser.categories.soilType.selected.value : null
                    });
                    types.push({
                        typeID: $scope.adviser.categories.sprinklerType.advisorTypeID,
                        subTypeID: $scope.adviser.categories.sprinklerType.selected.typeID,
                        customValue: $scope.adviser.categories.sprinklerType.selected.isCustom ? $scope.adviser.categories.sprinklerType.selected.value : null
                    });
                    types.push({
                        typeID: $scope.adviser.categories.sunExposureType.advisorTypeID,
                        subTypeID: $scope.adviser.categories.sunExposureType.selected.typeID,
                        customValue: $scope.adviser.categories.sunExposureType.selected.isCustom ? $scope.adviser.categories.sunExposureType.selected.value : null
                    });
                    zoneProxy.saveAndGetRecommendation($scope.deviceId, $scope.zoneId, types)
                        .success(function (data) {
                            $scope.openRecomendation();
                           
                            $scope.ladda.byZone = false;
                            data = data.body;
                            $scope.adviser.suggestions.suggestion_TotalWeeklyMinutes = data.suggestion_TotalWeeklyMinutes;
                            $scope.adviser.suggestions.suggestion_TotalWeeklyDays = data.suggestion_TotalWeeklyDays;
                            $scope.adviser.suggestions.suggestion_MaximumCycleMinutes = data.suggestion_MaximumCycleMinutes;
                            $scope.adviser.suggestions.suggestion_SoakTimeMinutes = data.suggestion_SoakTimeMinutes;
                            $scope.adviser.current.current_TotalWeeklyMinutes = data.current_TotalWeeklyMinutes;
                            $scope.adviser.current.current_WateringDays = data.current_WateringDays;
                            $scope.adviser.current.maxCycleTime = data.maxCycleTime;
                            $scope.adviser.current.maxSoakTime = data.maxSoakTime;
                        });
         
                    
                  
                }
                //*********************************************************************************************
                $scope.openRecomendation = function () {
                    $scope.hideRecLink = false;
                    $scope.showHideRecommendation = true;
                }
               // *********************************************************************************************
                $scope.closeRecomendation = function () {
                    $scope.hideRecLink = true;
                    $scope.showHideRecommendation = false;
                }
            }],
            //************************************************link***************************************
            link: function (scope, element, attrs, ngModel) {
               
            }
        };//return
    }
})(angular);

(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.device')
        .directive('setTime', setTimeFactory);
    /*******************************************************************************************************************************************************************/
    function setTimeFactory() {

        return {
            restrict: 'A',
            scope: {
                callback: "&",
            },
            templateUrl: 'app/modules/module.device/setTime/setOnlineTime.html',
            controller: ['$scope', function ($scope) {
                //************************************Attribute**********************************
                $scope.time = {
                    "Hours": 0,
                    "Minutes": 1,
                    "Seconds": 0
                }
                //************************************addHours**********************************
                $scope.addHours = function () {
                    if ($scope.time.Hours < 99) {
                        $scope.time.Hours++;
                    } else {
                        $scope.time.Hours = 0;
                    }
                }
                //************************************subHours**********************************
                $scope.subHours = function () {
                    if ($scope.time.Hours > 0) {
                        $scope.time.Hours--;
                    }
                }
                //************************************addMinutes**********************************
                $scope.addMinutes = function () {
                    if ($scope.time.Minutes < 59) {
                        $scope.time.Minutes++;
                    } else {
                        $scope.time.Minutes = 0;
                    }
                }
                //************************************subMinutes**********************************
                $scope.subMinutes = function () {
                    if ($scope.time.Minutes > 0) {
                        $scope.time.Minutes--;
                    } else {
                        $scope.time.Minutes = 59;
                    }
                }
                //************************************addMinutes**********************************
                $scope.addSeconds = function () {
                    if ($scope.time.Seconds < 59) {
                        $scope.time.Seconds++;
                    } else {
                        $scope.time.Seconds = 0;
                 
                    }
                }
                //************************************subMinutes**********************************
                $scope.subSeconds = function () {
                    if ($scope.time.Seconds > 0) {
                        $scope.time.Seconds--;
                    } else {
                        $scope.time.Seconds = 0;
                    }
                }
                $scope.save = function () {
                    $scope.callback()($scope.time);
                }
               

            }],
            link: function (scope, element, attrs) {
            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.filters')
        .filter('flowFilter', function () {

            return function (param, Type) {
                var newFlow = 0;
                switch (Type) {
                    case 0:
                        newFlow = param / 1000;
                        newFlow = newFlow.toFixed(1);
                        break;
                    case 1:
                        newFlow = param / 1000;
                        newFlow = newFlow.toFixed(2);
                        break;
                    case 2:
                        newFlow = param / 1000;
                        newFlow = newFlow.toFixed(2);
                        break;
                    case 3:
                        newFlow = param / 1000;
                        newFlow = newFlow.toFixed(2);
                        break;
                }

                return newFlow;
            };
        }).filter('secToStr', function () {

            return function (seconds) {
                var hourStr = "00:";
                var minStr='';
                var secStr = '';
                var hour = parseInt((seconds / 3600));
                var rest = seconds % 3600;
                var min = rest / 60;
                var sec = rest % 60;
                if (hour > 0 && hour <= 9) {   //1 digit
                    hourStr = '0' + hour.toString() + ":";
                } else if (hour > 9 ) {
                    hourStr = hour.toString()+":";
                }
                if (min > 9) {  // more than 1 digits
                    minStr = min.toString();
                } else {
                    minStr = '0'+min.toString();
                }
                if (sec > 9) {  // more than 1 digits
                    secStr = sec.toString();
                } else {
                    secStr = '0' + sec.toString();
                }

                return hourStr+minStr + ':' + secStr;
            };
        })
    /*******************************************************************************************************************************************************************************/

})(angular);

(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.httpProxies')
        .provider('baseProxy', baseProxy);


    //////////////// JavaScript //////////////

    function baseProxy() {

        var translateProvider;

        var _global = {
            data: {


                serverUri: ROOT_ADDR.SYSTEM_MF_API,
                serverMF: ROOT_ADDR.MF_API,
                serverXci: ROOT_ADDR.XCI_API,
                GoogleKey: "AIzaSyC4GOEIPbjen7-vzEPh4CbOGQCgl-_oyKE"
            }
        };
        function getObjArrayOfProperty(obj) {
            var arr = [];
            var i = 0;
            for (var property in obj) {
                arr[i] = property;
                i++;
            }
            return arr;
        }
        function buildPinLocation(lat, lan) {
            while(lan < -180) {
                lan=lan+360
            }
            while (lan > 180) {
                lan = lan - 360
            }
            return {
                latitude: lat,
                longitude: lan
            };
        }
       
        function timeConverter(UNIX_timestamp) {
            var a = new Date(UNIX_timestamp).toLocaleDateString();
          
            return a;
        }
        
        function buildLocalizedURI(uri, method, data) {
            var req = {
                method: method || 'GET',
                url: uri,
                headers: {
                    'Accept-Language': translateProvider.Settings.locale + ',en;q=0.8'
                },
                data: data

            }

            return req;
        }




        function buildLocation(lat, lan) {
            return {

                MapCenter: buildPinLocation(lat, lan),
                zoomLevel: 12,
                mode: "roadMap",
                autoBounds: true
            }

        };

        function saveManualMap(lat, lan, zoomLevel, mode, autoBounds) {
            return {

                MapCenter: buildPinLocation(lat, lan),
                zoomLevel: zoomLevel,
                mode: mode,
                autoBounds: autoBounds
            }

        };



        function convertToStringTime(time) {
            var hours = String(Math.floor(time / 3600));
            var min = String(Math.floor((time % 3600) / 60));
            if (hours.length == 1)
                hours = "0" + hours;
            if (min.length == 1)
                min = "0" + min;

            return hours + ":" + min;

        }

        function convertFromStringTime(time) {
            var d = new Date("1/1/2000 " + time);
          

            return d.getMinutes() * 60 + d.getHours() * 3600;

        }
        return {
            $get: ['$http', 'translate', function ($http, translate) {

                translateProvider = translate;

                //interface
                return {
                    Global: _global,
                    buildPinLocation: buildPinLocation,
                    buildLocation: buildLocation,
                    saveManualMap: saveManualMap,
                    buildLocalizedURI: buildLocalizedURI,
                    timeConverter: timeConverter,
                    convertToStringTime: convertToStringTime,
                    convertFromStringTime: convertFromStringTime,
                    getObjArrayOfProperty: getObjArrayOfProperty

                };
            }]
        }
    }
})(angular);






(function (angular) {
    'use strict';

    angular.module('module.main')
      .directive('generalClick', generalClickFactory);

    /**********************************************************************************************************************************************************************/
    function generalClickFactory() {


        return {
            restrict: 'A',
            link: function (scope, element, attr) {
                $('#dragbar').css({ marginLeft: $('.main-content').css('marginLeft') });
                var i = 0;
                var dragging = false;



               
                //****************************closeMessage*********************************************
                function closeMessage(target) {
                    if (target.parents(".messageSidebar").length || target.hasClass("messageSidebar")) {

                    }
                    else if (target.parents(".openMessage").length) {
                        $('#body').css({ 'overflow-y': 'hidden' });
                       
                        if ($('#page-sidebar').css("right") == "0px") {
                            $('#page-sidebar').css("right", "-500px");
                            //element.removeClass('open');
                        } else {
                            $('#page-sidebar').css("right", "0px");
                            //element.addClass('open');
                        }
                    }
                    else {
                        $('#page-sidebar').css("right", "-500px");
                        $('#users').attr("style", { right: "0px" });
                        if (target.parents('#ToggelApp').length >= 1) {
                            $('#body').css({ 'overflow-y': 'hidden' });
                        }
                        else if (target.parents('#main-navigation-menu').length >= 1 && target.parents('.sub-menu').length < 1) {
                            $('#body').css({ 'overflow-y': 'hidden' });
                        }

                        else {
                            $('#body').css({ 'overflow-y': 'auto' });
                        }
                        
                    }
                }
                //*****************************scrollToDiv*****************************************************
                function scrollToDiv(target) {

                    if (target.parents("#previewList").length || target.parents("#previewMap").length || target.parents("#previewSquares").length) {
                        $('html,body').animate({
                            scrollTop: $("#siteDevicesPanel").offset().top
                        }, 'slow');
                    }
                    if (target[0].id=='addDeviceGo') {
                        $('html,body').animate({
                            scrollTop: $("#addDeviceModalFooter").offset().top
                        }, 'slow');
                    }

                    
            

                }
                //****************************closeMessage*********************************************
                function closeSmallMenue(target) {
                    if ( (target[0].id == 'openSmallMenue') && ( $('#smallMenue').css( 'display') == 'none' ) ) {
                        $('#smallMenue').css({ 'display': "block" });
                    } else if (target.parents(".current-user").length || target.parents(".color").length) {
                        $('#smallMenue').css({ 'display': "block" });
                    }
                   
                    else {
                        $('#smallMenue').css({ 'display': "none" });
                    }
                }
               
                //**********************************************************************************************




                $("body").click
                (
                  function(e)
                  {
                      var target = $(e.target);
                      closeMessage(target);
                      scrollToDiv(target);
                      closeSmallMenue(target);
                

                    
                  }
                );
               
            }
        }

    }
})(angular);
(function (angular) {

    mi = angular
        .module('module.main')
        .controller('mainController', ['$scope', '$state','mainRouter', '$interval', 'profileProxy', 'user', 'mainProvider', mainController]);

    function mainController($scope,$state,mainRouter, $interval, profileProxy, user, mainProvider) {
        $scope.openMenu = false;
        //****************************************************************************************

        //$interval(function () {
        //    user.Messages.messageNum++;
        //}, 1000);

        $scope.messageInfo = user.Messages;

        //*************************************************************************************
        $scope.user = user.getUser();
        //*************************************************************************************
        function closeMenu() {
            $scope.openMenu = false;
        }
        //*************************************************************************************
        function delete_cookie(name) {
            document.cookie = name + '=; expires=Thu, 01 Jan 1970 00:00:01 GMT;';
        }
        //*************************************************************************************
        $scope.goToProfile = function () {
            fixLoadingOn("Profile");
            window.location = MAIN_LINKS.PROFILE.link+"?ReturnUrl="+window.location.href;
        }
        //**************************************************************************************
        $scope.nevigateToHomePage = function () {
            switch (mainProvider.ExchangeNevigation.data.loginExchangeView) {
                case "Device":
                    if (mainProvider.ExchangeNevigation.data.type == "GSI" || mainProvider.ExchangeNevigation.data.type == "GSI-AG") {
                        $state.go('device.GSI_device.status', { deviceId: mainProvider.ExchangeNevigation.data.id, typeName: mainProvider.ExchangeNevigation.data.type });
                    }
                    else if (mainProvider.ExchangeNevigation.data.type == "XCI" || mainProvider.ExchangeNevigation.data.type == "XCI-WIFI") {
                        
                        $state.go('device.XCI_device.online', { deviceId: mainProvider.ExchangeNevigation.data.id, typeName: mainProvider.ExchangeNevigation.data.type });
                    }
                    break;
                case "Site":
                    $state.go('site.preview.map', { siteId: mainProvider.ExchangeNevigation.data.id });
                    mainRouter.callkey("tree", mainProvider.ExchangeNevigation.data.id);
                    break;
                case "Project":
                    $state.go('site.preview.map', { siteId: mainProvider.ExchangeNevigation.data.id });
                    mainRouter.callkey("tree", mainProvider.ExchangeNevigation.data.id);
                    break;
                case "Welcome":
                    $state.go('welcome');
                    break;
            }
            
        }
        //*************************************************************************************
        $scope.logOut = function () {
            fixLoadingOn("Login");
            window.location = MAIN_LINKS.LOGIN.link + "&returnUrl=" + ROOT_ADDR.SYSTEM_MF_ROOT;
        }
        //*************************************************************************************
        $scope.timer = function (openMenu) {
            if (openMenu == true) {
                $scope.openMenu = true;
               
                window.setTimeout(function () {
                    closeMenu();
                }, 6000);
            } else {
                $scope.openMenu = false;
               
            }


        }
    
       
        //***************************************************************************************

    }
})(angular);







(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.main')
        .provider('mainProvider', mainProvider);


    //////////////// JavaScript //////////////


    function mainProvider() {


        return {
            $get: function () {
                var _currentSite = {
                    data: {
                       
                    }
                };
                var _currentDevice = {
                    data: {
                       
                    }
                };
                var _currentZone = {
                    data: {

                    }
                }

                var _ExchangeNevigation = {
                    data: {
                        loginExchangeView: "",
                        id: ""
                      
                    }
                }
                
               

                //interface
                return {

                    CurrentSite: _currentSite,
                    CurrentDevice: _currentDevice,
                    CurrentZone: _currentZone,
                    ExchangeNevigation: _ExchangeNevigation
                    
                };
            }
        }
    }
})(angular);

(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.main')
        .provider('mainRouter', mainRouter);


    //////////////// JavaScript //////////////


    function mainRouter() {


        return {
            $get: function () {
              
                var callbacks = [];

                //********************************************
                function _register(description,fn) {
                    callbacks.push({ callback: fn, key: description })

           
                }

                //********************************************
                function _callkey(description,data) {
                    for (var i = 0; i < callbacks.length;i++) {
                        if (callbacks[i].key == description) {
                            return callbacks[i].callback(data)
                        }
                    }
                }

               

                //interface
                return {
                    register: _register,
                    callkey:_callkey
                };
            }
        }
    }
})(angular);

(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.main')
        .provider('onlineProvider', onlineProvider);



    //////////////// JavaScript //////////////


    function onlineProvider() {


        return {
            $get: ['siteProxy', 'deviceProxy', '$interval', function (siteProxy, deviceProxy, $interval) {

                var callbacks = [];
                var socket;
                var onlineList = null;
                var onlineDevice = null;
                var siteId = null;
                var deviceId = null;
                var diffUTC = {def:0}; // miliseconds 1000 = 1 sec
   

                function _getDiffUTC() {
                    return diffUTC.def;
                }
                //******************************
                function _setDiffUTC(diffUtc) {
                    diffUTC.def = diffUtc;
                }
                //*****************************************
                function publishDeviceEvents(callback, pObj) {
                    for (var i = 0; i < pObj.events.length; i++) {
                        pObj.events[i].data.sn = pObj.sn;
                        _callCode(pObj.events[i].code, pObj.events[i].data, callback);
                    }
                }
                //******************************************
                function publishDevicesCachedEvents(callback) {
                    for (var i = 0 ; i < onlineList.length ; i++) {
                        publishDeviceEvents(callback, onlineList[i]);
                    }
                }
                //******************************************
                function _init(ServerUrl, Token) {
                    socket = io.connect(ServerUrl, {
                        query:
                        {
                            clientTime: new Date().getTime(),
                            Token: Token
                    
                        }
                    });
                    //***************************************
                    socket.on('server_ready', function (data) {
                     
                        _setDiffUTC(data.diffUTC);
                     
                    });
                    socket.on('reconnect_failed', function () {
                        alert('online server connection failed!')
                    });
                    socket.on('site_event', function (data) {
                        data.event.sn = data.sn;
                        _callCode(data.code, data.event);

                    });
                    socket.on('device_event', function (data) {
                        data.event.sn = data.sn;
                        _callCode(data.code, data.event);
                    });


                }
                //************************************************
                function _findCallback(codesArr, id, who, fn) {
                    var callbackObject = null;
                    for (var i = 0; i < callbacks.length; i++) {
                        if (callbacks[i].componnent == who) {
                            callbackObject = callbacks[i];
                            callbackObject.callback = fn;
                            callbackObject.isPublish = false;
                            break;
                        }
                    }
                    if (!callbackObject) {

                        callbackObject = { callback: fn, codes: codesArr, componnent: who, isPublish: false };
                        callbacks.push(callbackObject);
                    }

                    return callbackObject;
                }
                //**********************************************
                function _resetState() {
                    callbacks = [];
                    onlineList = null;
                    onlineDevice = null;
                    siteId = null;
                    deviceId = null;
                }
                //********************************************
                function _registerSite(codesArr, id, who, fn) {
                    if (siteId != id) {
                        _resetState();
                        siteId = id;
                        _startSite(siteId);
                    }
                    var callbackObject = _findCallback(codesArr, id, who, fn);

                    var now = new Date().getTime();

                    if (onlineList) { // get from server 
                        if (now - onlineList.time > 3000) { // the onlineList is not enogth updated                            
                            _getSiteOnlineStatus();
                        } else {
                            publishDevicesCachedEvents(callbackObject);
                        }

                    }
                }
                //***********************************************
                function _registerDevice(codesArr, id, who, fn) {

                    if (deviceId != id) {
                        _resetState();
                        deviceId = id;
                    
                        _startDevice(deviceId);
                    }

                    var callbackObject = _findCallback(codesArr, id, who, fn);

                    var now = new Date().getTime();
                    if (onlineDevice) { // get from server 
                        if (now - onlineDevice.time > 3000) { // the onlineList is not enogth updated
                            _getDeviceOnlineStatus();
                        } else {
                            publishDeviceEvents(callbackObject, onlineDevice);
                        }
                    }
                }
                //********************************************
                function _callCode(code, data, callback) {
                    if (callback) {
                        for (var j = 0; j < callback.codes.length ; j++) {
                            if (callback.codes[j] == code) {
                                data.code = code;
                                callback.callback(data);
                                break;
                            }
                        }
                    } else {
                        for (var i = 0; i < callbacks.length; i++) {
                            for (var j = 0; j < callbacks[i].codes.length ; j++) {
                                if (callbacks[i].codes[j] == code) {
                                    data.code = code;
                                    callbacks[i].callback(data);
                                    break;
                                }
                            }
                        }
                    }
                }
                //*******************************************
                function _startDevice(deviceID) {
                    onlineDevice = null;
                    socket.emit('register_device', deviceID);
                    _getDeviceOnlineStatus();
                }
                //************************************
                function _startSite(siteID) {
                    onlineList = null;
                    socket.emit('register_site', siteID);
                    _getSiteOnlineStatus();
                }
                //************************************
                function _getSiteOnlineStatus() {
                    siteProxy.getSiteOnlineStatus(siteId)
                      .success(function (data) {
                          data.time = new Date().getTime(); //time of object last update
                          onlineList = data;

                          // run on all calbackes if we have callback that didnt published than publish now
                          for (var i = 0; i < callbacks.length; i++) {
                              if (!callbacks[i].isPublish) {
                                  publishDevicesCachedEvents(callbacks[i]);
                              }
                          }
                      });
                }
                //******************************************
                function _getDeviceOnlineStatus() {
                    deviceProxy.getDeviceOnline(deviceId)
                        .success(function (data, status, headers, config) {
                            data.time = new Date().getTime(); //time of object last update
                            onlineDevice = data;
                    

                            // run on all calbackes if we have callback that didnt published than publish now
                            for (var i = 0; i < callbacks.length; i++) {
                                if (!callbacks[i].isPublish) {
                                    publishDeviceEvents(callbacks[i], onlineDevice);
                                }
                            }
                        }).error(function (data, status, headers, config) {

                        });
                }


                //*******************************************
                function _registerIntervalCallback(intervalCallback) {
                    intervalFunc = intervalCallback;
                }
                //********************************************
                function intervalFunc() {
                    return true;
                }
                //*******************************************
                var updateZonesInterval = $interval(function () {
                    intervalFunc();
                }, 1000);

                //interface
                return {
                    init: _init,
                    registerSite: _registerSite,
                    registerDevice: _registerDevice,
                    getDiffUTC: _getDiffUTC,
                    registerIntervalCallback: _registerIntervalCallback
              


                };
            }]
        }
    }
})(angular);

(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.main')
        .provider('user', user);


    //////////////// JavaScript //////////////
    

   function user() {

      
        return {
            $get: ['profileProxy', function (profileProxy) {
                var _currentUser = {
                    info: {
                       
                    }

                }
                var _messages = {
                    messageNum: 0,
                    messagesList:''
                }
                var _userAndSite = {
                    siteID:'',
                    sharingData: {},
                    
                }
                //*******************************************
                function _saveSharingData(siteID, sharingData) {
                    _userAndSite.siteID = siteID;
                    _userAndSite.sharingData = sharingData;

                }
                //*******************************************
                function _getSharingData() {
                   
                    return _userAndSite;

                }
                //********************************************
                function getMessagesInfo() {
                    profileProxy.GetMessageNum()
                   .success(function (data) {
                       _messages.messageNum = data.body;

                   });
                }

                //********************************************
                function _getUser() {
                    return _currentUser;
                }
                //*****************************************
                function _setUser(data) {
                    _currentUser.info = data;
                }
                //******************************************
                function _reload() {
                    getMessagesInfo();
                  
                }

                _reload();

                //interface
                return {
                 
                    setUser: _setUser,
                    getUser:_getUser,
                    Messages: _messages,
                    saveSharingData: _saveSharingData,
                    getSharingData:_getSharingData,
                    reload: _reload              
                };
            }]
        }
    }
})(angular);
(function (angular) {
    'use strict';

    angular.module('module.widgets')
      .directive('allMessages', allMessagesFactory);

    /**********************************************************************************************************************************************************************/
    function allMessagesFactory() {

        return {
            restrict: 'A',
            templateUrl: 'app/modules/module.message/allMessages.html',
            link: function (scope, element, attr) {

              
                element.bind('blur', function () {
                    if ($('#page-sidebar').css("right") == "-500px") {
                        $('#page-sidebar').css("right", "0px");
                        //element.removeClass('open');
                    }
                });
                
               
               
            }
        }

    }
})(angular);
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.message')
        .directive('gmap1', gmapFactory);

    /************************************************************************************************************************************************************************/
    function gmapFactory() {

        return {
            restrict: 'A',
            require: '?ngModel',
            transclude: true,



            template: '<div id="map-canvas-transfer" style="height: 300px"></div> ',
         
            replace: true,
       
            link: function (scope, element, attrs, ngModel) {
         
                scope.createMap = function (lat ,lan,zoom) {




                    var markers = [];
           
                            var obj = {};
                            obj.lat = lat;
                            obj.lng = lan;
                            markers.push(obj);
                 

                    var mapOptions = {
                        center: new google.maps.LatLng(lat, lan),
                        zoom: zoom,
                        mapTypeId: google.maps.MapTypeId.ROADMAP

                    };
            
                    var map = new google.maps.Map(element[0], mapOptions);

                    for (var i = 0; i < markers.length; i++) {
                        var data1 = markers[i]
                        var myLatlng = new google.maps.LatLng(data1.lat, data1.lng);
                        var marker = new google.maps.Marker({
                            position: myLatlng,
                            map: map,
                            siteId: data1.siteId,
                            draggable: false,
                            animation: google.maps.Animation.DROP
                        });
                       
                       
                      
                    }

          
                }
                ngModel.$render = function () {

                    var lan = parseFloat(attrs.lan);
                    var zoom = parseFloat(attrs.zoom);
                    scope.createMap(ngModel.$viewValue, lan, zoom);
                };
            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);
(function (angular) {
    'use strict';

    angular.module('module.widgets')
      .directive('messageList', messageListFactory);

    /**********************************************************************************************************************************************************************/
    function messageListFactory() {

        return {
            restrict: 'A',
            templateUrl: 'app/modules/module.message/messageList.html',
            controller: ['$scope', 'profileProxy','mainRouter', function ($scope, profileProxy,mainRouter) {
                //***************************************Attributs***************************************
                $scope.load = 1;
                //***************************************GetMessages***************************************
                $scope.GetMessages = function (load) {

                    profileProxy.GetMessages(load)
                              .success(function (data) {
                                  $scope.Messages = data.body.messages;
                              });
                }
                //********************************************************
                mainRouter.register("messageList", function (data) {
                    $scope.GetMessages($scope.load);
                });

                //******************************************************************************
                $scope.showMsg = function (id) {
                    profileProxy.GetMessage(id)
                              .success(function (data) {
                                  //$scope.Message = data.body;
                                  $scope.$broadcast('Message', data.body);
                              });
                    
                }
                //***************************************loadMore***************************************
                $scope.loadMore = function () {
                    $scope.load++;
                    $scope.GetMessages($scope.load);

                }
                $scope.GetMessages($scope.load);
            }],
            link: function (scope, element, attr) {

                element.bind('click', function (e) {
                    if ($(e.target).closest('.media').length) {
                        $(element).parent().css({ right: 270 });
                    } else {

                    }
                })
               
            }
        }

    }
})(angular);
(function (angular) {
    'use strict';

    messageTypeFactory.$inject = ['$log'];
    angular.module('module.widgets')
      .directive('messageType', messageTypeFactory);

    /**********************************************************************************************************************************************************************/
    function messageTypeFactory($log) {

        return {
            restrict: 'A',
            templateUrl: 'app/modules/module.message/messageType.html',
            controller: ['$scope', 'projectProxy', 'profileProxy', '$state', 'user','mainRouter', function ($scope, projectProxy, profileProxy, $state, user, mainRouter) {
                //********************************************Attributs*******************************
                $scope.newMsg = {
                    content: ""
                };
                $scope.newProjectName = {
                    name:""
                }
             
                //********************************************$on('Message')*******************************
                //mainRouter.register("oneMessage", function (data) {
                //    if (data.record.folderingTypeID == 3 || data.record.folderingTypeID == 4) {
                //        $scope.GetAllProjects();
                //        $scope.type = { state: "exists" };
                //    }
                //    $scope.fullMessage = data;
                //    $scope.message = data.record;
                //});
                //*****************************************************************************************
                $scope.$on('Message', function (event, data) {
                    if (data.record.folderingTypeID == 3 || data.record.folderingTypeID == 4) {
                        $scope.GetAllProjects();
                        $scope.type = { state: "exists" };
                    }
                    $scope.fullMessage = data;
                    $scope.message = data.record;
                });
                ///********************************************AcceptSite********************************************************************
                $scope.Accept = function (status,type) { // status 3 for reject 2 for accept
                        var obj = {
                            record:{
                                projectName: "",
                                projectId: ""
                            },
                            MessageID: $scope.fullMessage.messageID,
                            MessageType: $scope.fullMessage.messageType,
                            Status: status
                        }
            
                        if (type== 'exists') {
                            obj.record.projectName = $scope.choosenProjectName;
                            obj.record.projectId = $scope.choosenProjectId;
                        }
                        else {
                           
                            obj.record.projectName = $scope.newProjectName.name;
                        
                        }
                        profileProxy.acceptMessage(obj)
                                          .success(function (data) {
                                              if (data.body.projectID) { //accept
                                                  //nevigate to the new site
                                                  $state.go('site.preview.map', { siteId: data.body.projectID });
                                                  // add the new site to the tree (refresh tree)
                                                  mainRouter.callkey("tree", {});
                                                 

                                              } else { // reject

                                              }


                                              //general operation in case of accept/reject
                                              //**********************************************
                                              //close messages div
                                              if ($('#page-sidebar').css("right") == "0px") {
                                                  $('#page-sidebar').css("right", "-500px");
                                                  //element.removeClass('open');
                                              } else {
                                                  $('#page-sidebar').css("right", "0px");
                                                  //element.addClass('open');
                                              }
                                              // dec 1 message from messages list(refresh messageList)
                                              mainRouter.callkey("messageList", {});

                                              //dec 1 message from message counter
                                              user.Messages.messageNum = user.Messages.messageNum - 1;
                        });
                    //send to server
                    //clean the object
                   
                   

                }
                ///************************************************GetAllProjects****************************************************************
                $scope.GetAllProjects = function () {
                    projectProxy.GetAllProjects()
                                       .success(function (data) {
                                           if (data.body.length > 0) {
                                               $scope.type.state = 'exists';
                                               $scope.projectsList = data.body;
                                               $scope.choosenProjectName = $scope.projectsList[0].name;
                                               $scope.getChoosenProject($scope.projectsList[0].projectID, $scope.choosenProjectName);
                                           } else {
                                               $scope.type.state = 'new';
                                           }
                                           });

                }


                ///**************************************************getChoosenProject**************************************************************
                $scope.getChoosenProject = function (projectId, projectName) {
                    $scope.choosenProjectId = projectId;
                    $scope.choosenProjectName = projectName;

                }
                ///****************************************************************************************************************
            }],
            link: function (scope, element, attr) {

                element.bind('click', function (e) {

                    if ($(e.target).hasClass('sidebar-back')) {
                        $('#users').attr("style", { right: "0px" });
                    } else {

                    }
                })
            }
        }

    }
})(angular);

(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.menuNavigation')
        .directive('addProject', addProjectFactory);
    /************************************************************************************************************************************************************************/
    function addProjectFactory() {
        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.navbar/addProject.html',
            controller: ['$scope', '$filter', 'projectProxy', '$state', 'mainRouter', function ($scope, $filter, projectProxy, $state, mainRouter) {

                //************************************************Attributs*******************
                $scope.ProjectName = "";
                $scope.ladda = {
                    'addProject':false
                }
                $scope.validation = false;
                //************************************************functions*******************
                //***********************showPosition(Inner)****************
                function showPosition(position) {
                    $scope.centerLat = position.coords.latitude;
                    $scope.centerLng = position.coords.longitude;
                }
                //***********************getLocation(Inner)****************
                function getLocation() {
                    if (navigator.geolocation) {
                        navigator.geolocation.getCurrentPosition(showPosition);
                    } else {
                        toastr.error($filter('translate')('toastrErrMsgGet'));
                        //California, United States
                        $scope.centerLat = 36.542750;
                        $scope.centerLng = -119.800532;
                    }
                }
                //***********************saveNewProject(Outer)****************
                $scope.saveNewProject = function (func, addProjectform) {
                    if (addProjectform) {
                        $scope.ladda.addProject = true;
                        projectProxy.saveNewProject($scope.ProjectName, $scope.centerLat, $scope.centerLng)
                         .success(function (data) {
                             toastr.success($filter('translate')('toastrSuccessMsgAdd'));
                           
                             $state.go('site.preview.map', ({ siteId: data.body.projectID }));
                             mainRouter.callkey("tree", data.body.projectID);
                             $scope.ladda.addProject = false;
                             $scope.ProjectName = "";
                             $('#addProject').modal('hide');
                         }).error(function (data, status, headers, config) {
                             toastr.error($filter('translate')('toastrErrMsgGet'));
                         });
                    } else {
                        $scope.validation = true;
                    }
                }
                //*************************************************************
                $scope.resetValidation = function (addProjectform) {
                    for (var att in addProjectform.$error) {
                        if (addProjectform.$error.hasOwnProperty(att)) {
                            addProjectform.$setValidity(att, true);
                        }
                    }

                   
               
                }
                //************************************************

                getLocation();


            },
        ]};
    }
})(angular);







(function (angular) {

    mi = angular
        .module('module.menuNavigation')
        .controller('menuController', menuController);
    menuController.$inject = ['$scope', 'projectProxy', 'directiveComm', '$state', 'siteProxy', '$timeout', 'mainRouter']
    function menuController($scope, projectProxy, directiveComm, $state, siteProxy, $timeout, mainRouter) {
        //*******************************************************Attributs***********************************************************
        //$scope.siteId = $state.params.siteId;
        $timeout(function () {
            getSiteName($state.params.siteId);
        }, 200);

        $scope.text = "";
        var $pageArea;
        $scope.pagerFlag = false;
        var PageSize = 10;
        $scope.currentPage = 1;
        $scope.MenuConnector = directiveComm.CreateConnector();
        $scope.ladda = {
            "siteList": false,
        };
        ///*******************************************************$on siteToMenu(Outer)****************************************
        $scope.$on('projectChangeName', function (event, data) {
            for (var i = 0; i < $scope.projectsList.length; i++) {
                if ($scope.projectsList[i].projectID == data.projectID) {
                    $scope.projectsList[i].name = data.projectName;
                    break;
                }
            }
        });
        ///*******************************************************$on siteToMenu(Outer)****************************************
        $scope.$on('siteToMenu', function (event, data) {
            for (var i = 0; i < $scope.projectsList.length; i++) {
                if ($scope.projectsList[i].projectID == data.projectID) {
                    delete data.projectID;
                    $scope.projectsList[i].sites.unshift(data);
                    break;
                }
            }
        });
        ///*******************************************************$on projectToMenu(Outer)****************************************
        $scope.$on('projectToMenu', function (event, data) {
            $scope.projectsList.unshift(data);
        });
        ///*******************************************************$on projectToMenu(Outer)****************************************
        $scope.$on('deleteProjectFromMenu', function (event, data) {
            for (var i = 0; i < $scope.projectsList.length; i++) {
                if ($scope.projectsList[i].projectID == data.projectID) {

                    break;
                }
            }
        });
        //***********************usageConnector.SetCallbackUp(Outer)****************
        $scope.MenuConnector.SetCallbackUp(function (pageNumber) {

            GetProjects(pageNumber, $scope.text);

        });
        //******************************************************************************
        $scope.bodyScroll = function () {
            $('#body').css({ 'overflow-y': 'auto' });
        }
        //********************************************************************************
        //function to adjust the template elements based on the window size
        var runElementsPosition = function () {
            $windowWidth = $(window).width();
            $windowHeight = $(window).height();
            $pageArea = $windowHeight - $('body > .navbar').outerHeight() - $('body > .footer').outerHeight();

            runContainerHeight();

        };
        runElementsPosition();
        ///*******************************************************runContainerHeight(Inner)***********************************************
        function runContainerHeight() {
            mainContainer = $('.main-content > .container');
            mainNavigation = $('.main-navigation');
            if ($pageArea < 760) {
                $pageArea = 760;
            }
            if (mainContainer.outerHeight() < mainNavigation.outerHeight() && mainNavigation.outerHeight() > $pageArea) {
                mainContainer.css('min-height', mainNavigation.outerHeight());
            } else {
                mainContainer.css('min-height', $pageArea);
            };
            if ($windowWidth < 768) {
                mainNavigation.css('min-height', $windowHeight - $('body > .navbar').outerHeight());
            }
            $("#page-sidebar .sidebar-wrapper").css('height', $windowHeight - $('body > .navbar').outerHeight()).scrollTop(0).perfectScrollbar('update');
        };
        ///**********************************************************GetProjects(Inner)*******************************************************
        function GetProjects(currentPage, freeText) {

            projectProxy.GetProjects(currentPage, freeText, PageSize)
                             .success(function (data) {
                                 $scope.totalProjects = data.totalProjects;
                                 $scope.projectsList = data.projects;
                                 $scope['abc'] = $scope['abc'] || {};

                                 findCurrentSite($scope.projectsList);
                                 var pagesNumber = Math.ceil($scope.totalProjects / PageSize);
                                 $scope.currentPage = data.currentPageNumber;
                                 if ($scope.totalProjects > PageSize) {
                                     $scope.pagerFlag = true;
                                     $scope.MenuConnector.CallbackDown($scope.currentPage, PageSize, $scope.totalProjects);
                                 }
                             });
        }
        //*****************************************************************************************************
        function findCurrentSite(projects) {

            if (projects == null) {
                return 0;
            }
            for (var i = 0; i < projects.length; i++) {
                if (projects[i].siteID == $state.params.siteId) {
                    projects[i].selected = 'selected';
                    $scope['abc'].currentNode = projects[i];
                    return true;
                } else {
                    findCurrentSite(projects[i].sites)
                }
            }
        }
        //*****************************************************************************************************
        function getSiteName(siteId) {
            siteProxy.getSiteName(siteId)
              .success(function (data, status, headers, config) {
                  $scope.choosenProject = data.body.projectID;
              })
              .error(function (data, status, headers, config) {

              });
        }
        ///*************************************************************filterSearch(Outer)***************************************************
        $scope.filterSearch = function (txt) {
            $scope.currentPage = 1;
            $scope.text = txt;
            GetProjects($scope.currentPage, txt || "");
        }
        ///*************************************************************toggleNavigationMenu(Outer)********************************************
        $scope.toggleNavigationMenu = function (event) {

            var toggleIcon = $(event.target).parent();

            if (toggleIcon[0].localName == "li") {
                toggleIcon = $(event.currentTarget);
            }
            if ($(toggleIcon).parent().children('div').hasClass('sub-menu') && ((!$('body').hasClass('navigation-small') || $windowWidth < 767) || !$(toggleIcon).parent().parent().hasClass('main-navigation-menu'))) {
                if (!$(toggleIcon).parent().hasClass('open')) {
                    $(toggleIcon).parent().addClass('open');
                    $(toggleIcon).parent().parent().children('li.open').not($(toggleIcon).parent()).not($('.main-navigation-menu > li.active')).removeClass('open').children('div').slideUp(200);
                    $(toggleIcon).parent().children('div').slideDown(200, function () {
                        runContainerHeight();
                    });
                } else {
                    if (!$(toggleIcon).parent().hasClass('active')) {
                        $(toggleIcon).parent().parent().children('li.open').not($('.main-navigation-menu > li.active')).removeClass('open').children('div').slideUp(200, function () {
                            runContainerHeight();
                        });
                    } else {
                        $(toggleIcon).parent().parent().children('li.open').removeClass('open').children('div').slideUp(200, function () {
                            runContainerHeight();
                        });
                    }
                }
            }
        }

        //************************************************toggleNavbar(Outer)**********************************************************************
        $scope.toggleNavbar = function () {
            if (!$('body').hasClass('navigation-small')) {
                $('body').addClass('navigation-small');
                
            } else {
                $('body').removeClass('navigation-small');
            };
        }
        ///**************************************************************getChoosenProject(Outer)**************************************************
        $scope.getChoosenProject = function (projectId, projectName) {
            $scope.choosenProjectId = projectId;
            $scope.choosenProjectName = projectName;
        }
        //****************************************************************************************************************************
        $scope.goToSite = function (siteId) {
            fixLoadingOn("goToSite", siteId);
            getSiteName(siteId);
            $state.go('site.preview.map', { siteId: siteId });


        }

        //*********************************************************************************************************************
        GetProjects($scope.currentPage, $scope.text);

        //*********************************************************************************************************





    }
})(angular);







(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.menuNavigation')
        .directive('navbarDirective', navbarDirective);
        
    /**********************************************************************************************/
    function navbarDirective() {

        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.navbar/navbar.html',

            controller: ['$scope', 'projectProxy', 'directiveComm', '$state', 'siteProxy', '$timeout','mainRouter','$stateParams',
                function ($scope, projectProxy, directiveComm, $state, siteProxy, $timeout, mainRouter, $stateParams) {

                   
                    var $windowWidth;
                    var $windowHeight
                    var $pageArea
                    $scope.text = "";
                    $scope.pagerFlag = false;
                    var PageSize = 2;
                    $scope.currentPage = 1;
                    $scope.MenuConnector = directiveComm.CreateConnector();
                    $scope.ladda = {
                        "siteList": false,
                    };
                    
                    mainRouter.register("tree", function (siteId) {
                        //new get project that have siteid parameter from state.param and give list of project with the right page number
                        GetProjectsById(siteId, PageSize);
                        
                    });
                    mainRouter.register("choosenSiteId", function (siteId) {
                       
                        findCurrentSite($scope.projectsList, siteId)
                    });
                    //*******************************************************************************
                    $timeout(function () {
                        if ($state.params.siteId) {
                            $scope.targetSiteTransfer = $state.params.siteId
                            GetProjectsById($scope.targetSiteTransfer, PageSize);
                        }else
                        {
                            GetProjects(1, "");
                        }
                        if ($stateParams.siteId) {
                            $scope.siteId = $stateParams.siteId;
                        }

                        
                    }, 500);
                    ///*******************************************************$on siteToMenu(Outer)****************************************
                    $scope.$on('projectChangeName', function (event, data) {
                        for (var i = 0; i < $scope.projectsList.length; i++) {
                            if ($scope.projectsList[i].projectID == data.projectID) {
                                $scope.projectsList[i].name = data.projectName;
                                break;
                            }
                        }
                    });
                    ///*******************************************************$on siteToMenu(Outer)****************************************
                    $scope.$on('siteToMenu', function (event, data) {
                        for (var i = 0; i < $scope.projectsList.length; i++) {
                            if ($scope.projectsList[i].projectID == data.projectID) {
                                delete data.projectID;
                                $scope.projectsList[i].sites.unshift(data);
                                break;
                            }
                        }
                    });
                    ///*******************************************************$on projectToMenu(Outer)****************************************
                    $scope.$on('projectToMenu', function (event, data) {
                        $scope.projectsList.unshift(data);
                    });
                    ///*******************************************************$on projectToMenu(Outer)****************************************
                    //***********************usageConnector.SetCallbackUp(Outer)****************
                    $scope.MenuConnector.SetCallbackUp(function (pageNumber) {
                        GetProjects(pageNumber, $scope.text);
                    });
                    //****************************************************************************
                    $scope.bodyScroll = function () {
                        $('#body').css({ 'overflow-y': 'auto' });
                    }
                    //****************************************************************************
                    //function to adjust the template elements based on the window size
                    var runElementsPosition = function () {
                        $windowWidth = $(window).width();
                        $windowHeight = $(window).height();
                        $pageArea = $windowHeight - $('body > .navbar').outerHeight() - $('body > .footer').outerHeight();

                        runContainerHeight();

                    };
                    //***********************************************************************
                    runElementsPosition();
                    ///*******************************************************runContainerHeight(Inner)***********************************************
                    function runContainerHeight() {
                       var mainContainer = $('.main-content > .container');
                       var mainNavigation = $('.main-navigation');
                        if ($pageArea < 760) {
                            $pageArea = 760;
                        }
                        if (mainContainer.outerHeight() < mainNavigation.outerHeight() && mainNavigation.outerHeight() > $pageArea) {
                            mainContainer.css('min-height', mainNavigation.outerHeight());
                        } else {
                            mainContainer.css('min-height', $pageArea);
                        };
                        if ($windowWidth < 768) {
                            mainNavigation.css('min-height', $windowHeight - $('body > .navbar').outerHeight());
                        }
                        $("#page-sidebar .sidebar-wrapper").css('height', $windowHeight - $('body > .navbar').outerHeight()).scrollTop(0).perfectScrollbar('update');
                    };
                    ///**********************************************************GetProjects(Inner)*******************************************************
                    function GetProjects(currentPage, freeText) {
                        projectProxy.GetProjects(currentPage, freeText, PageSize)
                                         .success(function (data) {
                                             PageSize = data.currentPageSize;
                                             $scope.totalProjects = data.totalProjects;
                                             $scope.projectsList = data.projects;
                                             $scope[$scope.type] = $scope[$scope.type] || {};
                                             findCurrentSite($scope.projectsList, $state.params.siteId);
                                             var pagesNumber = Math.ceil($scope.totalProjects / PageSize);
                                             $scope.currentPage = data.currentPageNumber;
                                             if ($scope.totalProjects > PageSize) {
                                                 $scope.pagerFlag = true;
                                                 $scope.MenuConnector.CallbackDown($scope.currentPage, PageSize, $scope.totalProjects);
                                             }
                                         });
                    }
                    //****************************************************************************
                    function GetProjectsById(siteId, pageSize) {
                        projectProxy.GetProjectsById(siteId, pageSize)
                                         .success(function (data) {
                                             PageSize = data.currentPageSize;
                                             $scope.totalProjects = data.totalProjects;
                                             $scope.projectsList = data.projects;
                                             $scope[$scope.type] = $scope[$scope.type] || {};
                                             findCurrentSite($scope.projectsList, $state.params.siteId);
                                             var pagesNumber = Math.ceil($scope.totalProjects / PageSize);
                                             $scope.currentPage = data.currentPageNumber;
                                             if ($scope.totalProjects > PageSize) {
                                                 $scope.pagerFlag = true;
                                                 $scope.MenuConnector.CallbackDown($scope.currentPage, PageSize, $scope.totalProjects);
                                             }
                                         });
                    }
                    //*****************************************************************************************************
                    function findCurrentSite(projects, siteId) {
                        $scope.siteId = siteId;
                        if (projects == null) {
                            return 0;
                        }
                        for (var i = 0; i < projects.length; i++) {
                         
                            if ((projects[i].siteID == siteId) && ($scope.type == 'abc')) {
                                $scope.choosenProject = projects[i].rootProjectID;

                                $scope.siteName = projects[i].name;
                               
                                
                                $scope[$scope.type].currentNode = projects[i];
                                if ((projects[i].siteID == projects[i].rootProjectID) && ($scope.theSelected)) {
                                    //find and clear the selected item if exist
                                    $scope.theSelected.selected = null;
                                } else {
                                    projects[i].selected = 'selected';
                                    $scope.theSelected = projects[i];
                                }
                                return true;
                            } else {
                                findCurrentSite(projects[i].sites, siteId)
                            }
                        }
                    }
                    //*****************************************************************************************************
                    function getSiteName(siteId) {
                        siteProxy.getSiteName(siteId)
                          .success(function (data, status, headers, config) {
                              $scope.choosenProject = data.body.projectID;
                          })
                          .error(function (data, status, headers, config) {

                          });
                    }
                   
                    ///*************************************************************filterSearch(Outer)***************************************************
                    $scope.filterSearch = function (txt) {
                        $scope.currentPage = 1;
                        $scope.text = txt;
                        GetProjects($scope.currentPage, txt || "");
                    }
                    ///*************************************************************toggleNavigationMenu(Outer)********************************************
                    $scope.toggleNavigationMenu = function (event) {

                        var toggleIcon = $(event.target).parent();

                        if (toggleIcon[0].localName == "li") {
                            toggleIcon = $(event.currentTarget);
                        }
                        if ($(toggleIcon).parent().children('div').hasClass('sub-menu') && ((!$('body').hasClass('navigation-small') || $windowWidth < 767) || !$(toggleIcon).parent().parent().hasClass('main-navigation-menu'))) {
                            if (!$(toggleIcon).parent().hasClass('open')) {
                                $(toggleIcon).parent().addClass('open');
                                $(toggleIcon).parent().parent().children('li.open').not($(toggleIcon).parent()).not($('.main-navigation-menu > li.active')).removeClass('open').children('div').slideUp(200);
                                $(toggleIcon).parent().children('div').slideDown(200, function () {
                                    runContainerHeight();
                                });
                            } else {
                                if (!$(toggleIcon).parent().hasClass('active')) {
                                    $(toggleIcon).parent().parent().children('li.open').not($('.main-navigation-menu > li.active')).removeClass('open').children('div').slideUp(200, function () {
                                        runContainerHeight();
                                    });
                                } else {
                                    $(toggleIcon).parent().parent().children('li.open').removeClass('open').children('div').slideUp(200, function () {
                                        runContainerHeight();
                                    });
                                }
                            }
                        }
                    }
                    //********************************************************************************************************
                    $scope.togelAction = function () {
                        var toggleIcon = $(event.target).parent();

                        if (toggleIcon[0].localName == "li") {
                            toggleIcon = $(event.currentTarget);
                        }

                        if ($(toggleIcon).children('i').hasClass('clip-chevron-down')) {
                            $(toggleIcon).children('i').removeClass('clip-chevron-down')
                            $(toggleIcon).children('i').addClass('clip-chevron-up');
                        } else {
                            $(toggleIcon).children('i').removeClass('clip-chevron-up')
                            $(toggleIcon).children('i').addClass('clip-chevron-down');
                        }
                        if ($(toggleIcon).parent().children('ul').hasClass('sub-menu') && ((!$('body').hasClass('navigation-small') || $windowWidth < 767) || !$(toggleIcon).parent().parent().hasClass('main-navigation-menu'))) {
                            if (!$(toggleIcon).parent().hasClass('open')) {
                                $(toggleIcon).parent().addClass('open');
                                
                                $(toggleIcon).parent().children('ul').slideDown(200, function () {
                                    runContainerHeight();
                                });
                            } else {
                                if (!$(toggleIcon).parent().hasClass('active')) {
                                    $(toggleIcon).parent().parent().children('li.open').not($('.main-navigation-menu > li.active')).removeClass('open').children('ul').slideUp(200, function () {
                                        runContainerHeight();
                                    });
                                } else {
                                    $(toggleIcon).parent().parent().children('li.open').removeClass('open').children('ul').slideUp(200, function () {
                                        runContainerHeight();
                                    });
                                }
                            }
                        }
                    }
                    //************************************************toggleNavbar(Outer)**********************************************************************
                    $scope.toggleNavbar = function () {
                        if (!$('body').hasClass('navigation-small')) {
                            $('body').addClass('navigation-small');
                            $('#main-navigation-menu').hide();
                            $('#dragbar').hide();
                            mainRouter.callkey("reloadMap", {});

                        } else {
                            $('body').removeClass('navigation-small');
                            $('#main-navigation-menu').show();
                            $('#dragbar').show();
                        };
                    }
                    ///**************************************************************getChoosenProject(Outer)**************************************************
                    $scope.getChoosenProject = function (projectId, projectName) {
                        $scope.choosenProjectId = projectId;
                        $scope.choosenProjectName = projectName;
                    }
                    //****************************************************************************************************************************
                    $scope.goToSite = function (p ,event) {
                        
                        if (p.sites) {
                            $scope.toggleNavigationMenu(event);
                        }
                        if ($scope.navbarType == 'menu') {
                            if (p.selected != "selected") {
                                $scope.siteId = p.siteID || p.projectID;
                                findCurrentSite($scope.projectsList, $scope.siteId);
                                fixLoadingOn("goToSite", p.siteID || p.projectID);
                            }
                           
                            $scope.choosenProject = p.rootProjectID;
                           // getSiteName(p.siteID);
                            $state.go('site.preview.map', { siteId: p.siteID || p.projectID });
                        } else if(($scope.navbarType == 'checkBox')) {
                            if (p.parentSiteID == null) { //project
                                $scope.targetSiteTransfer = p.siteID;
                            }
                        }
                        else if (($scope.navbarType == 'alerts')) {
                            if (p.parentSiteID == null) { //project
                                mainRouter.callkey("treeAlertForSiteID", p.siteID);
                            }
                        }
                        


                    }
                    //*********************************************************************************************************************
                    //**  new get project that have siteid parameter from state.param and give list of project with the right page number
                    //GetProjects($scope.currentPage, $scope.text);
                    
                    //****************************************************************************************
                    $scope.localTransfer = function () {
                        if ($scope.targetSiteTransfer != -1) {
                            siteProxy.localTransfer($state.params.siteId, $scope.targetSiteTransfer)
                                 .success(function (data) {



                                 });
                        }
                     
                    }
                    //**********************************************************************
                    $scope.DeleteSite = function () {
                 
                        siteProxy.DeleteSite($stateParams.siteId)
                          .success(function (data, status, headers, config) {
                              $scope.exchange();
                              $('#deleteSite').modal('hide');
                             

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


                }],
                    //***************************************************link************************
            link: function (scope, element, attrs, ngModel) {

           
                scope.navbarType = attrs.atr;
                if (scope.navbarType == 'menu') {
                    scope.type = 'abc';
               }else{
                    scope.type = 'bcd';
               }
               
               
               

            }
        };
    }

                 /*******************************************************************************************************************************************************************************/

})(angular);







(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.menuNavigation')
        .directive('togelDirective', togelDirectiveFactory);
    function togelDirectiveFactory() {
        var runToDoAction = function () {
            if ($(this).parents('.navbar-collapse')) {
                $(this).parents('.navbar-collapse').collapse('hide');
                var bool = $('#body').css('overflow-y');
                if (bool == 'hidden') {
                    $('#body').css({ 'overflow-y': 'auto' });
                } else {
                    $('#body').css({ 'overflow-y': 'hidden' });
                }
                
            }
           
        };
       

        return {
            restrict: 'A',

            link: function (scope, element, attrs) {
                runToDoAction();
             
                element.bind('click', runToDoAction);
            }
        };
    }
})(angular);








(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    projectSettingsFactory.$inject = ['$log'];
    angular.module('module.project')
        .directive('projectSettings', projectSettingsFactory);
    /*******************************************************************************************************************************************************************/
    function projectSettingsFactory($log) {

        return {
            restrict: 'EA',
            require: '?ngModel',
            templateUrl: 'app/modules/module.project/projectSettings.html',

            controller: ['$scope', 'projectProxy', 'siteProxy', '$filter',
                function ($scope, projectProxy, siteProxy, $filter) {

                //************************************************attributs*******************
                $scope.ladda = {
                    "share": false,
                    "transfer": false  
                }
                $scope.addUser = {
                    email: "",
                    roleViewOnly: false,
                    roleModify: false,
                    roleControlRT: false,
                    roleAdmin: false
                }
                $scope.userEmailTransfer = {address:""};
                $scope.emailExistTransfer = true;
                $scope.userEmailShare;
                $scope.emailExistShare = true;
               //************************************************functions*******************
               //*************************************************getSharingList****************
                $scope.getSharingList = function (projectId) {
                    siteProxy.getSharingList(projectId)
                                       .success(function (data) {
                                           $scope.usersList = data.body;
                    });

                }
                //*****************************************************transferProject(Outer)****************
                $scope.getTransferStatus = function (projectId) {
                    siteProxy.getTransferStatus(projectId)
                                       .success(function (data) {
                                           $scope.transferStatus = data.body;
                                          
                                       });
                }
                //*****************************************************transferProject(Outer)****************
                $scope.transferProject = function (projectId) {
                  
                        $scope.ladda.transfer = true;
                        siteProxy.transferProject(projectId, $scope.userEmailTransfer.address)
                                      .success(function (data) {
                                          if (!data.body) {
                                              var msgNum = data.messages[0].code;
                                              toastr.error($filter('translate')(msgNum));
                                             
                                          }
                                          $scope.ladda.transfer = false;
                                          $scope.transferObj = data.body;
                                          $scope.ladda.transfer = false;
                                          $scope.transferStatus = data.body;
                                      }).error(function (data, status, headers, config) {

                                      });
                   
                }
                //*************************************************cancelTransfer(Outer)****************
                $scope.cancelTransfer = function (projectId) {
                    siteProxy.cancelTransfer(projectId)
                                       .success(function (data) {
                                          
                                           $scope.transferStatus.transferStatus = 0;
                                       });

                }
                //*************************************************cancelTransfer(Outer)****************
                $scope.deleteUser = function (userId) {
                    siteProxy.deleteUser($scope.ProjectId, userId)
                                         .success(function (data) {
                                             for (var i = 0 ; i < $scope.usersList.length; i++) {
                                                 if ($scope.usersList[i].linkedUserID == userId) {
                                                     $scope.usersList.splice(i, 1);
                                                 }
                                             }
                                         });

                }
                //*************************************************shareProject(Outer)****************
                $scope.shareProject = function () {


                    if ($scope.shareForm.$valid) {
                        $scope.ladda.share = true;
                        //send to server
                        $scope.ladda.share = false;
                        $scope.emailValidationShare = false;
                    } else {
                        $scope.emailValidationShare = true;
                    }
                }
          
                //*************************************************cancelTransfer(Outer)****************
                $scope.sendShareUser = function () {
                    if ($scope.addUser.email.length > 0) {
                        var temp = $scope.usersList.slice(0);
                        temp.push($scope.addUser);
                        siteProxy.sendShareUser($scope.ProjectId, temp)
                            .success(function (data) {
                            });
                    } else {
                        siteProxy.sendShareUser($scope.ProjectId, $scope.usersList)
                           .success(function (data) {
                               if ($scope.addUser.email.length > 1) {
                                  
                               }
                           });
                    }
                }
               
             
                }],
            //***************************************************link************************
            link: function (scope, element, attrs, ngModel) {

                if (!ngModel) return; // do nothing if no ng-model
                ngModel.$render = function () {

                    scope.ProjectId = ngModel.$viewValue;
                    fixLoadingOff();
                    scope.getSharingList(scope.ProjectId);
                    scope.getTransferStatus(scope.ProjectId);
                    // must read thoose value before
                    //waiting for transffer and watting for share
                    

                };


            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);








(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site')
        .directive('addSite', ['$filter', addSiteDFactory]);
    /***********************************************************************************************************************************************************************/
    function addSiteDFactory($filter) {
        return {
            restrict: 'EA',
            require: '?ngModel',
            templateUrl: 'app/modules/module.site/addSite.html',

            controller: ['$scope','$rootScope', 'siteProxy', '$filter', '$state','mainRouter',
                function ($scope, $rootScope, siteProxy, $filter, $state, mainRouter) {
                    //************************************************attributs*******************
                    $scope.siteName = "";
                    $scope.addSiteLadda = false;
                    $scope.validation = false;
                    //************************************************functions*******************


                    //***********************showPosition(Outer)****************
                    $scope.saveNewSite = function (func, addsiteform) {
                        if(addsiteform){
                        $scope.addSiteLadda = true;
                        siteProxy.CreateNewSite($scope.ProjectId, $scope.siteName)
                         .success(function (data) {
                             func();
                             $scope.addSiteLadda = false;
                             var obj = {};
                             obj.projectID = $scope.ProjectId;
                             obj.siteID = data.body;
                             obj.name = $scope.siteName;
                             obj.sharingData = {
                                 hasRole_Control: true,
                                 hasRole_Modify: true,
                                 hasRole_View: true,
                                 isPending: false
                             }
                             $state.go('site.preview.map', { siteId: data.body });
                             mainRouter.callkey("tree", data.body);
                          
                         });
                        } else {
                            $scope.validation = true;
                        }
                    }
                    ////***********************showPosition(Inner)****************
                    //function showPosition(position) {

                    //    $scope.centerLat = position.coords.latitude;
                    //    $scope.centerLng = position.coords.longitude;


                    //}
                    ////***********************getLocation(Inner)****************
                    //function getLocation() {
                    //    if (navigator.geolocation) {
                    //        navigator.geolocation.getCurrentPosition(showPosition);
                    //    } else {
                    //        toastr.error($filter('translate')('toastrErrMsgGet'));
                    //        //California, United States
                    //        $scope.centerLat = 36.542750;
                    //        $scope.centerLng = -119.800532;
                    //    }
                    //}

                    //getLocation();


                }],
            link: function (scope, element, attrs, ngModel) {

                if (!ngModel) return;
                ngModel.$render = function () {

                    scope.ProjectId = ngModel.$viewValue;
                    scope.ProjectName = attrs.pname;

                };

            }

        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);








(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site')
        .directive('leftMessages', leftMessagesFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function leftMessagesFactory() {

        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.site/leftMessages.html',

            controller: ['$scope', '$http', '$filter', '$stateParams', 'siteProxy', 'deviceProxy', function ($scope, $http, $filter, $stateParams, siteProxy, deviceProxy) {

               
            }
            ]
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);







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

(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    reportsFactory.$inject = ['$log'];
    angular.module('module.site.reports')
        .directive('reports', reportsFactory);
    /***************************************************************************************************************************************************************/
    function reportsFactory($log) {



        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.site/module.Reports/Reports.html',

            controller: ['$scope', '$stateParams', 'projectProxy', 'baseProxy', 'siteProxy', '$filter', 'user', function ($scope, $stateParams, projectProxy, baseProxy, siteProxy, $filter, user) {
            
                $scope.reportsTypes = [
                { mainType: "monthly Reports", subType: [{ name: "Monthly Consumption-Controllers" }, { name: "Monthly Consumption-Stations" }, { name: "Monthly Consumption-Programs" }] },
                { mainType: "Daily Reports", subType: [{ name: "Daily Consumption-Controllers" }, { name: "Daily Consumption-Stations" }, { name: "Daily Consumption-Programs" }] },
                { mainType: "Fertilization Reports", subType: [{ name: "Monthly Consumption With Fertilizer -Controllers" }, { name: "Daily Consumption With Fertilizer -Controllers" }, { name: "Daily Fertilization-Stations" }, { name: "Monthly Fertilization-Stations" }] }

                ]
            }],
            link: function (scope, element, attrs, ngModel) {
               

            }




        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);







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
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    translateDirectiveFactory.$inject = ['$log'];
    angular.module('module.translate')
        .directive('translateDirective', translateDirectiveFactory);



    function translateDirectiveFactory($log) {
        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.translate/translate.html',

            controller:['$scope', '$translate','tmhDynamicLocale', function ($scope, $translate,tmhDynamicLocale) {
                $scope.selectedLanguage = $translate.use();
                $scope.Img = localStorage.getItem("selectedLanguageImgSrc") || 'http://www.transcriptionstudio.com/wp-content/uploads/2011/06/USA-FLAG.jpg';

              
                $scope.changeLanguage = function (len , img) {
                    $scope.selectedLanguage = len;
                    $translate.use(len);
                    tmhDynamicLocale.set(len);
                    localStorage.setItem("selectedLanguage", len);
                    $scope.Img = img;
                    localStorage.setItem("selectedLanguageImgSrc", img);
                    //window.location.reload();
                };




                

            }],
            link: function (scope, element, attrs, ngModel) {


            }




        };

    }
})(angular);








(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.translate')
        .provider('translate', translate);


    //////////////// JavaScript //////////////

    function translate() {
        var _Settings = {
            GMT_Offset: '',
        };
        function _UpdateGMT_Offset(offset) {
            _Settings.GMT_Offset = offset;
        };
        var date = {
            'startUnix': '',
            'endUnix': ''
        };
        function changeLanguage  (str) {
            //use parameter needs to be part of a known locale Eg: en-UK, en, etc
            $translate.use(str);
        };
        function convertUnixToTime(millisecondsMidnight) {    //only for clock(read) not for date
            
            var d = new Date(0);
            var minutes = millisecondsMidnight / 60;
            d.setHours(minutes / 60);
            d.setMinutes(minutes % 60);
            return d;
        };
        function secsToMinutes(sec) {
            return sec/60;
        };
        function minutesToSecs(min) {
            return min * 60;
        };
        function stringToUnix(sec) { //only for clock(write) not for date
            
            if (sec.indexOf("M") > -1) {
                var n = sec.indexOf("M");
                sec=sec.insertAt(n-1, " ");
            }
            var time = new Date("October 13, 2014" + " " + sec);
            return time.getSeconds() + (60 * time.getMinutes()) + (60 * 60 * time.getHours());
        };


        function fullDateStringToUnixServer(date, timeStr) {

            if (timeStr.indexOf("M") > -1) {
                var n = timeStr.indexOf("M");
                timeStr = timeStr.insertAt(n - 1, " ");
            }
            var localTime = new Date(date + " " + timeStr);
            var GmtAbs = localTime.getTimezoneOffset() * 60 * 1000;
        
            return localTime.getTime() - GmtAbs;
        }
        function FixUnixGmtFromServer(UnixMili) {

            var d = new Date();
            var GmtAbs = d.getTimezoneOffset() * 60 * 1000;

            return UnixMili - GmtAbs;
        }

       

        function clockType(locale) {
            if (locale.DATETIME_FORMATS.shortTime.indexOf("a") != -1) {
                return "AMPM";
            }
            return "ordinary";
        }
      
        String.prototype.insertAt = function (index, string) {
            return this.substr(0, index) + string + this.substr(index);
        }
       
        //***********************getLastYear(Outer)****************
        function getLastYear() {
           
            var localTime = new Date();
            var GmtAbs = localTime.getTimezoneOffset() * 60 * 1000;
            var lastYear = localTime.setFullYear(localTime.getFullYear() - 1)
            date.endUnix = localTime.getTime() - GmtAbs;
            date.startUnix = lastYear - GmtAbs;
            return date;
        }
        //***********************getLastMonth(Outer)****************
        function getLastMonth() {
            
            var localTime = new Date();
            var GmtAbs = localTime.getTimezoneOffset() * 60 * 1000;
            var lastMonth = localTime.setMonth(localTime.getMonth() - 1)
            date.endUnix = localTime.getTime() - GmtAbs;
            date.startUnix = lastMonth - GmtAbs;
            return date;
            //***********************getLastWeek(Outer)****************   
        }
        function getLastWeek() {
            
            var localTime = new Date();
            var GmtAbs = localTime.getTimezoneOffset() * 60 * 1000;
            var lastWeek = new Date(localTime.getFullYear(), localTime.getMonth(), localTime.getDate() - 7);
            date.endUnix = localTime.getTime() - GmtAbs;
            date.startUnix = lastWeek- GmtAbs;
            return date;
        }
     
        return {
            $get: function () {


                //interface
                return {
                    UpdateGMT_Offset: _UpdateGMT_Offset,
                    convertUnixToTime: convertUnixToTime,
                    secsToMinutes: secsToMinutes,
                    fullDateStringToUnixServer:fullDateStringToUnixServer,
                    minutesToSecs:minutesToSecs,
                    stringToUnix: stringToUnix,
                    clockType: clockType,
                
                    getLastYear: getLastYear,
                    getLastMonth: getLastMonth,
                    getLastWeek: getLastWeek,
                    FixUnixGmtFromServer: FixUnixGmtFromServer
                    
                    
    
                  

                };
            }
        }
    }
})(angular);


//translate methods:

//{{myDate | date:'fullDate'}}
//{{money | currency}}
//<p>ffff</p>
//<p translate="varibleInside" translate-values="{count:3}"></p>
//<p>{{"varibleInside" | translate:{ count :6 } }}</p>
//$scope.text = $translate('varibleInside' , { count:3 });
// <p>{{"varibleInside" | translate:{ count :6 , sum:9} }}</p>
//in en file "varibleInside":"you have {{count}} new messages and also {{sum}} miss calls",



(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.weather.forecast')
        .directive('oneday', onedayFactory);
    function onedayFactory() {
        return {
            restrict: 'A',
            scope: {
                onedayweather:'='
            },
            templateUrl: 'app/modules/module.weather/foreCast/oneday.html',
            controller: ['$scope', '$locale', 'user', function ($scope, $locale, user) {
                $scope.locale = $locale;
                $scope.tempUnitID = user.getUser().info.tempUnitID;
            }
        ]};              
    }
})(angular);

(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    weatherDirectiveFactory.$inject = ['$log'];
    angular.module('module.weather.forecast')
        .directive('weatherDirective', weatherDirectiveFactory);
    /**********************************************************************************************************************************************************************/
    function weatherDirectiveFactory($log) {

        return {
            restrict: 'EA',
            require: '?ngModel',
            templateUrl: 'app/modules/module.weather/foreCast/weather.html',
            controller: ['$scope', '$http', '$stateParams', 'baseProxy', 'siteProxy', 'weatherProxy', '$filter', 'coordinator', 'translate','user', function ($scope, $http, $stateParams, baseProxy, siteProxy, weatherProxy, $filter, coordinator, translate,user) {
                //*********************************************Attribute****************
                $scope.bigView = false;
                $scope.AdvanceSettings = false;
                $scope.ladda = {
                    'saveWeather':false
                }
                $scope.siteAdd = {
                    siteName:""
                }
                $scope.applyHierarchy={val:false};
                $scope.yyy = true;
                $scope.tempUnitID = user.getUser().info.tempUnitID;
                var dt = new Date();
                var secs = dt.getSeconds() + (60 * dt.getMinutes()) + (60 * 60 * dt.getHours());

                //********************************************Functions******************
                //*********************************************coordinator.SubscribeEvent**************************
                coordinator.SubscribeEvent("SiteLocationChanged", function (event) {
                    var location = {
                        lat: event.lat,
                        lan: event.lan
                    } 
                    $scope.GetWeatherDetails($scope.isDevice, location);
                });
                //*********************************************getAddress(Inner)**************************
                function getAddress(data) {
                    var lat = data.body.location.lat.toString();
                    var lan = data.body.location.lon.toString();
                  
                    var latlng = new google.maps.LatLng(lat, lan);
                    var geocoder = geocoder = new google.maps.Geocoder();
                    geocoder.geocode({ 'latLng': latlng }, function (results, status) {
                        if (status == google.maps.GeocoderStatus.OK) {
                            if (results[1]) {
                                $scope.siteAdd.siteName = results[1].formatted_address;
                                $scope.$apply();
                            }
                        } else {
                            $scope.siteAdd.siteName = lat + ", " + lan;
                            $scope.$apply();
                        }
                    });
                }
                //***************************************************************************************
                function chooseIcon(days) {
                    for (var i = 0; i < days.length; i++) {
                        if(secs < 72000){
                            days[i].skyIconURL = days[i].iconData.day_Url;
                        } else {
                            days[i].skyIconURL = days[i].iconData.night_Url;
                        }
                    }
                }
                //*********************************************GetWeatherDetails(Inner)*******************
                $scope.GetWeatherDetails = function(isDevice,Location) {
                    var localTime = new Date();
                    var GmtAbs = localTime.getTimezoneOffset() * 60 * 1000;
                    ///*********************************************992 just for gsi temporery
                    if (isDevice) {
                        var id = $stateParams.deviceId;
                        
                    } else {
                        var id = $stateParams.siteId;
                    }
                    
                    weatherProxy.GetWeatherDetails(id, localTime.getTime() - GmtAbs, isDevice, Location, $scope.tempUnitID)
                   .success(function (data) {
                       $scope.date = $filter('date')(localTime.getTime() - GmtAbs, 'mediumDate', 'UTC');
                       $scope.days = data.body.forecastsData;
                       chooseIcon($scope.days);
                       if (!isDevice) {
                           weatherProxy.GetWeatherSettings(id)
                                 .success(function (data) {
                                     $scope.Savings = data.body.saving;
                                     $scope.Settings = data.body.settings;
                                     $scope.privilige = user.getSharingData().sharingData.roleModify;

                                 });
                       }
                       getAddress(data)
                      
                   });
                }
               
                //*********************************************toggleAdvanceSettings(Outer)*******************
                $scope.toggleAdvanceSettings = function () {
                    $scope.AdvanceSettings = !$scope.AdvanceSettings;
                }
                //*********************************************saveDetails(Outer)*******************
                $scope.saveDetails = function (func,valid) {


                    if (valid) {
                        $scope.validation = false;
                        $scope.ladda.saveWeather = true;
                        var siteId = $stateParams.siteId;
                        weatherProxy.SaveWeatherSettings(siteId, $scope.Settings, $scope.applyHierarchy.val)
                         .success(function (data, status, headers, config) {
                             $scope.ladda.saveWeather = false;
                             toastr.success('Weather Settings  Saved', 'Success!');
                             func();
                         })
                         .error(function (data, status, headers, config) {
                             toastr.error('Weather Settings Not Saved', 'Error!');
                             $scope.ladda.saveWeather = false;
                             func();
                         });
                    } else {
                        $scope.validation = true;
                    }
                }
                //*************************************************************************************
                $scope.showBigView = function () {
                    $scope.bigView = true;
                }
      
            }
            ],
            link: function (scope, element, attrs, ngModel) {
                scope.isDevice = attrs.param == 'device';
                scope.GetWeatherDetails(scope.isDevice);
            }


        };
    }
    /*******************************************************************************************************************************************************************************/

})(angular);







(function (angular) {
    'use strict';
angular.module('module.weather.forecast')
  .filter('precipitation', function () {
      return function (input) {
          switch (input) {
              case "Inch":
                  return "in";
              
              case "mm":
                  return "mm";

              case "Percent":
                  return "%"
          }
      };
  });

})(angular);
(function (angular) {
    'use strict';

    angular.module('module.widgets')
      .directive('addClass', addClassFactory);

    /**********************************************************************************************************************************************************************/
    function addClassFactory() {

        return {
            restrict: 'A',
            link: function (scope, element, attr) {

                element.bind('click', function (e) {
                    if ($(e.target).hasClass('selected')) {
                      
                    } else {
                        $(element).parent().find('*').each(function () {
                            $(this).removeClass('selected');
                        });
                        element.addClass('selected');
                    }
                })
            }
        }

    }
})(angular);
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('imgCheckbox', imgCheckboxFactory);
    /*******************************************************************************************************************************************************************/
    function imgCheckboxFactory() {

        return {
            restrict: 'EA',
            link: function (scope, element, attrs) {


                check_param(attrs.param);
                attrs.$observe('param', function (val) {
                    check_param(val);
                });

                function check_param(param) {
                    if (param == "false") { //read only
                        $(element).prop('readonly', true);


                    } else {
                        $(element).prop('readonly', false);
                        $(element).css("background-color", "white");
                    }
                }







            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);
(function (angular) {
    'use strict';

    angular.module('module.widgets')
      .directive('pen', penFactory);

    /**********************************************************************************************************************************************************************/
    function penFactory() {

        return {
            restrict: 'A',
            link: function (scope, element, attr) {

                element.bind('click', function () {
                    element.parent().parent().children('.Name').focus();
                })
            }
        }

    }
})(angular);
(function (angular) {
    'use strict';

    closeMainNevigationFactory.$inject = ['$log'];
    angular.module('module.widgets')
      .directive('closeMainNevigation', closeMainNevigationFactory);

    /**********************************************************************************************************************************************************************/
    function closeMainNevigationFactory($log) {

        return {
            restrict: 'A',
            link: function (scope, element, attr) {

                element.bind('click', function (e) {
                    if ($(e.target).hasClass('title') || $(e.target).hasClass("btn")) {
                        element.removeClass("in");
                        element.attr("aria-expanded", false);
                    } else {
                      
                    }
                })
            }
        }

    }
})(angular);
(function (angular) {
    'use strict';

    closeModelFactory.$inject = ['$log'];
    angular.module('module.widgets')
      .directive('closeModel', closeModelFactory);

    /*********************************************************************Weather****************************************************************************************************/
    function closeModelFactory($log) {

        return {
            restrict: 'A',
            link: function (scope, element, attr) {
            
                //scope.getZone = function (zoneId, zoneName) {
                //    alert('hhh');
                //}
                scope.dismiss = function () {
                    element.modal('hide');

                   // scope.getZone(1, 1);
                };
            }
        }

    }
})(angular);
(function (angular) {
    'use strict';

    closePanelFactory.$inject = ['$log'];
    angular.module('module.widgets')
      .directive('closePanel', closePanelFactory);

    /**********************************************************************************************************************************************************************/
    function closePanelFactory($log) {

        return {
            restrict: 'A',
            link: function (scope, element, attr) {
                scope.height  = element.parent().parent().parent().children('.panel-body').css("heigth");
                element.bind('click', function () {
                    
                    if( element.parent().parent().parent().children('.panel-body').css("display")=="none" )
                    {
                        element.parent().parent().parent().children('.panel-body').slideDown("fast");
                        element.removeClass('fa-chevron-down');
                        element.addClass('fa-chevron-up');
                    } else {
                        element.parent().parent().parent().children('.panel-body').slideUp("fast");;
                        element.removeClass('fa-chevron-up');
                        element.addClass('fa-chevron-down');
                    }
                })
            }
        }

    }
})(angular);
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    colorFactory.$inject = ['$log'];
    angular.module('module.widgets')
        .directive('color', colorFactory);



    function colorFactory($log) {
        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.widgets/color/changeColor.html',

            controller: ['$scope', function ($scope) {
            
              
                $scope.str = localStorage.getItem("css") || "Files/content/css/MF/colorGreyNew.css";
                if ($scope.str.indexOf("colorGreyNew.css")!=-1) {
                    localStorage.setItem('cssType', 'dark');
                } else {
                    localStorage.setItem('cssType', 'bright');
                }
                $scope.changeCssTo = function (col) {
                    switch (col) {
                        case 'Dark':
                            $scope.str = "Files/content/css/MF/colorGreyNew.css";
                            localStorage.setItem("css", "Files/content/css/MF/colorGreyNew.css");
                            localStorage.setItem('cssType', 'dark');
                            break;
                        case 'White':
                            $scope.str = "Files/content/css/MF/theme_light.css";
                            localStorage.setItem("css", "Files/content/css/MF/theme_light.css ");
                            localStorage.setItem('cssType', 'bright');
                            break;
                    }
                }





            }],
            link: function (scope, element, attrs, ngModel) {


            }




        };

    }
})(angular);
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    compareToFactory.$inject = ['$log'];
    angular.module('module.widgets')
        .directive('compareTo', compareToFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function compareToFactory($log) {

        return {
            require: "ngModel",
            scope: {
                otherModelValue: "=compareTo"
            },
            link: function (scope, element, attributes, ngModel) {

                ngModel.$validators.compareTo = function (modelValue) { //will run if someting change on confirm textfild
                    return modelValue == scope.otherModelValue; 
                };

                scope.$watch("otherModelValue", function () {
                    ngModel.$validate(); // run  ngModel.$validators.compareTo if somting change on password
                });
            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);










(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    datePickerDirectiveFactory.$inject = ['$log'];
    angular.module('module.widgets')
        .directive('datePickerDirective', datePickerDirectiveFactory);
    function datePickerDirectiveFactory($log) {

        return {
            restrict: 'EA',
            link: function (scope, element, attr) {
                element.datepicker({
                    dateFormat: '@',

                });
            }


        };//return
    }
})(angular);










(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    myDeleteConfirmFactory.$inject = ['$log'];
    angular.module('module.widgets')
        .directive('myDeleteConfirm', myDeleteConfirmFactory);



    function myDeleteConfirmFactory($log) {
        return {
            restrict: 'EA',
            require: '?ngModel',
            scope: {
                callback: "&"
            },
            templateUrl: 'app/modules/module.widgets/deleteConfirm/deleteConfirm.html',

            controller: ['$scope', 'siteProxy', function ($scope, siteProxy) {
                
                $scope.showValidation = false;
                $scope.Captcha = function() {
                    var alpha = new Array('A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z');
                    var i;
                    for (i = 0; i < 6; i++) {
                        var a = alpha[Math.floor(Math.random() * alpha.length)];
                        var b = alpha[Math.floor(Math.random() * alpha.length)];
                        var c = alpha[Math.floor(Math.random() * alpha.length)];
                        var d = alpha[Math.floor(Math.random() * alpha.length)];
                        var e = alpha[Math.floor(Math.random() * alpha.length)];
                        var f = alpha[Math.floor(Math.random() * alpha.length)];
                        var g = alpha[Math.floor(Math.random() * alpha.length)];
                    }
                    $scope.code = a + ' ' + b + ' ' + ' ' + c + ' ' + d + ' ' + e + ' ' + f + ' ' + g;
                    $scope.codeNotSpaces = removeSpaces($scope.code);
                }
                //***********************************************************************
                 $scope.getSiteName = function(siteId) {
                    siteProxy.getSiteName(siteId)
                      .success(function (data, status, headers, config) {
                          //$scope.siteName = data.body.siteName;
                          //$scope.projectOrSite = data.body.projectName;

                          if (data.body.projectID == data.body.siteID) { //delete project
                              $scope.projectOrSiteName = data.body.projectName;
                              $scope.type = "Project";
                          } else {
                              $scope.projectOrSiteName = data.body.siteName; // delete site
                              $scope.type = "Site";
                          }
                     
                        
                      })
                      .error(function (data, status, headers, config) {

                      });
                 }
                //**************************************************************************
                 $scope.getDeviceName = function (id) {
                     siteProxy.GetDeviceInfo(id)
                        .success(function (data) {
                            var devices = data.body.deviceListView;
                            for (var i = 0; i < devices.length; i++) {
                                if (devices[i].sn == id) {
                                    $scope.currentDevice = devices[i];
                                   
                                }
                            }
                        }).error(function (data, status, headers, config) {
                            toastr.error($filter('translate')('toastrErrMsgGet'));
                        });
                 }
                //***************************************************************************
                function ValidCaptcha() {
                    var string1 = removeSpaces($scope.code);
                    var string2 = removeSpaces($scope.myString);
                    if (string1 == string2) {
                        return true;
                    }
                    else {
                        return false;
                    }
                }
                function removeSpaces(string) {
                    return string.split(' ').join('');
                }

                $scope.confirm = function () {
                    $scope.showValidation = true;
                    if (ValidCaptcha()) {
                       
                        $scope.callback();
                        $scope.Captcha();
                    } else {
                        
                        $scope.Captcha();
                        
                    }
                    $scope.myString = "";
                }


                //************************
                $scope.Captcha();
            }],
            link: function (scope, element, attrs, ngModel) {

                if (!ngModel) return; // do nothing if no ng-model
                ngModel.$render = function () {
                    scope.myString = "";
                    scope.id = ngModel.$viewValue;  // siteId or sn
                    scope.text = attrs.str;
                    scope.text1 = attrs.str1;
                    scope.type = attrs.typeattr;
                    if (scope.id){
                        if (scope.type == 'site') {
                            scope.getSiteName(scope.id);
                        } else {
                            scope.getDeviceName(scope.id);
                        }
                    }

                };
               

            }




        };

    }
})(angular);
(function (angular) {
    'use strict';

    deleteRowFactory.$inject = ['$log'];
    angular.module('module.widgets')
      .directive('deleteRow', deleteRowFactory);

    /*********************************************************************Weather****************************************************************************************************/
    function deleteRowFactory($log) {

        return {
            restrict: 'A',
            link: function (scope, element, attrs, ngModel) {
              
            
                element.bind('click', function (event) {

                    if (element.parent().parent().find('.line').length != 0) {
                        element.parent().parent().find('.line').remove();
                    }
                    else {
                        var width = element.parent().parent().width() - 100;


                        var line = $('<div>')
                       .appendTo(element.parent().parent())
                       .addClass('line')

                       .width(width);
                    }
                   

                    $(window).resize(function () {
                        var width = element.parent().parent().width() - 100;
                        element.parent().parent().find('.line').width(width);
                    });
                   
                  












                    //var _html = "<div style=\"border-bottom: 3px solid black\">DELETED<div>";
                    //var hr = $(_html).insertBefore(element.parent());
                });
               
            }
        };

    }
})(angular);
//**************************************************NavBar*******************************
$('#dragbar').css({ marginLeft: $('.main-content').css('marginLeft') });
var i = 0;
var dragging = false;
$('#dragbar').mousedown(function (e) {
    e.preventDefault();

    dragging = true;

});

//*********************************************GsiDeviceStatusdragbar**********************
var Statusdragbar = false;



//****************General Mouse Events*****************************
$(document).mousemove(function (e) {
    //******NavBar***************
    if ((dragging) && ($('#dragbar').css("marginLeft") > '224px') && ($('#dragbar').css("marginLeft") < '317px')) {
        $('#dragbar').css("marginLeft", e.pageX + 2);
        $('.navigation-toggler').css("marginLeft", e.pageX - 30);
        $('.tree.menu').css("width", e.pageX + 2);
        $('.main-content').css("marginLeft", e.pageX + 2);
        $('#ghostbar').remove();

    }
    //******GsiDeviceStatusdragbar***********
    if (Statusdragbar) {
        var hanukiyaHeigth = $('.hanukiya').css("height");
        $('.hanukiya').css("height", e.pageY + 2);
    }
});
$(document).mouseup(function (e) {

    //******NavBar***************
    if (dragging) {
        if (($('#dragbar').css("marginLeft") <= '224px')) {
            $('.tree').css("width", '225px');
            $('#dragbar').css("marginLeft", '225px');
            $('.main-content').css("marginLeft", '225px');
            $('.navigation-toggler').css("marginLeft", "190px");
        }
        if (($('#dragbar').css("marginLeft") >= '290px')) {
            $('.tree').css("width", '289px');
            $('#dragbar').css("marginLeft", '289px');
            $('.main-content').css("marginLeft", '289px');
            $('.navigation-toggler').css("marginLeft", "255px");
        }
        dragging = false;
    }
    //******GsiDeviceStatusdragbar***********
    if (Statusdragbar) {
       
        Statusdragbar = false;
    }

    
});

(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    dropeDownFactory.$inject = ['$filter'];
    angular.module('module.widgets')
        .directive('dropeDown', dropeDownFactory);
    /**************************************************************************************************************************************************************/
    function dropeDownFactory($filter) {



        return {
            restrict: 'EA',
       

            link: function (scope, element, attrs, ngModel) {

               
                $(element).on({
                    "click": function (e) {
                        var target = $(e.target);
                        if (target.parents('.dropDownSearch').length >=1) {
                            e.stopPropagation();
                        }
                        
                    }
                });
            }
        };
    }
    /*******************************************************************************************************************************************************************************/

})(angular);








(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    editInputTextFactory.$inject = ['$log'];
    angular.module('module.widgets')
        .directive('editInputText', editInputTextFactory);
    /*******************************************************************************************************************************************************************/
    function editInputTextFactory($log) {

        return {
            restrict: 'A',
           
            link: function (scope, element, attrs) {
                
                var x = 0;
                var clickCallBack = attrs.editInputText;
                var btn = null;
                var originalValue;
                element.focusin(function () {
                    if (!btn) {
                        originalValue = element.val();
                        var str = "<input type='button' class='editGo' value='GO'/>";
                        btn = $(str).insertAfter(element);

                        btn.on("click", function () {
                            scope.$eval(clickCallBack);
                            originalValue = element.val();
                            btn.hide();
                            
                        });
                    }

                    btn.show();
                });
                element.focusout(function (event) {
               

                    window.setTimeout(function () {
                        btn.fadeOut(500);
                        element.val(originalValue);
                    }, 200);
                    
                   
                });                
            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    flipclockFactory.$inject = ['$log'];
    angular.module('module.widgets')
        .directive('flipclock', flipclockFactory);
    /*******************************************************************************************************************************************************************/
    function flipclockFactory($log) {

        return {
            restrict: 'EA',
            require: '?ngModel',

            link: function (scope, element, attrs, ngModel) {



               

                if (!ngModel) return;
                ngModel.$render = function () {
                 
                    var value = ngModel.$viewValue;
                    $(element).flipcountdown({ size: 'sm', tick: value });

                };

            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('gsiAccordion', gsiAccordionFactory);
    function gsiAccordionFactory() {

        var changeState = function () {
            if ($(this).children('.fa-chevron-circle-up').length == 1) {
                var i = $(this).children('.fa-chevron-circle-up');
                i.removeClass("fa-chevron-circle-up");
                i.addClass("fa-chevron-circle-down");
                var body = $(this).parents().parents().children('.gsi-panel-body');
                body.css({ 'display': 'none' });

            }
            else{
                var i = $(this).children('.fa-chevron-circle-down');
                i.removeClass("fa-chevron-circle-down");
                i.addClass("fa-chevron-circle-up");
                var body = $(this).parents().parents().children('.gsi-panel-body');
                body.css({ 'display': 'block' });
            }
                
                
 

        };


        return {
            restrict: 'A',

            link: function (scope, element, attrs) {
               

                element.bind('click', changeState);
                
            }
        };
    }
})(angular);
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    htmlApendFactory.$inject = ['$log'];
    angular.module('module.widgets')
        .directive('htmlApend', htmlApendFactory);
    /*********************************************************************************************************************************************************************/
    function htmlApendFactory($log) {

        return {
            restrict: 'A',

            link: function (scope, element, attrs) {
              
                var htmlString = attrs.htmlApend;
       
                $(htmlString).appendTo(element);
               
            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('imageSettings', imageSettingsFactory);
    /*******************************************************************************************************************************************************************/
    function imageSettingsFactory() {

        return {
            restrict: 'EA',
            require: '?ngModel',
            templateUrl: 'app/modules/module.widgets/imageSettings/imageSettings.html',
            link: function (scope, element, attrs, ngModel) {
               

                if (!ngModel) return;
                ngModel.$render = function () {
                    
                        scope.url = ngModel.$viewValue;
                     
                  

                };
            
            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);

/* jquery.nicescroll
-- version 3.4.0
-- copyright 2011-12-13 InuYaksa*2013
-- licensed under the MIT
--
-- http://areaaperta.com/nicescroll
-- https://github.com/inuyaksa/jquery.nicescroll
--
*/

(function(jQuery){

  // globals
  var domfocus = false;
  var mousefocus = false;
  var zoomactive = false;
  var tabindexcounter = 5000;
  var ascrailcounter = 2000;
  var globalmaxzindex = 0;
  
  var $ = jQuery;  // sandbox
 
  // http://stackoverflow.com/questions/2161159/get-script-path
  function getScriptPath() {
    var scripts=document.getElementsByTagName('script');
    var path=scripts[scripts.length-1].src.split('?')[0];
    return (path.split('/').length>0) ? path.split('/').slice(0,-1).join('/')+'/' : '';
  }
  var scriptpath = getScriptPath();

// derived by Paul Irish https://gist.github.com/paulirish/1579671 - thanks for your code!

  if (!Array.prototype.forEach) {  // JS 1.6 polyfill
    Array.prototype.forEach = function(fn, scope) {
      for(var i = 0, len = this.length; i < len; ++i) {
        fn.call(scope, this[i], i, this);
      }
    }
  }
  
  var vendors = ['ms','moz','webkit','o'];
  
  var setAnimationFrame = window.requestAnimationFrame||false;
  var clearAnimationFrame = window.cancelAnimationFrame||false;

  vendors.forEach(function(v){
    if (!setAnimationFrame) setAnimationFrame = window[v+'RequestAnimationFrame'];
    if (!clearAnimationFrame) clearAnimationFrame = window[v+'CancelAnimationFrame']||window[v+'CancelRequestAnimationFrame'];    
  });
  
  var clsMutationObserver = window.MutationObserver || window.WebKitMutationObserver || false;
  
  var _globaloptions = {
      zindex:"auto",
      cursoropacitymin:0,
      cursoropacitymax:1,
      cursorcolor:"#424242",
      cursorwidth:"5px",
      cursorborder:"1px solid #fff",
      cursorborderradius:"5px",
      scrollspeed:60,
      mousescrollstep:8*3,
      touchbehavior:false,
      hwacceleration:true,
      usetransition:true,
      boxzoom:false,
      dblclickzoom:true,
      gesturezoom:true,
      grabcursorenabled:true,
      autohidemode:true,
      background:"",
      iframeautoresize:true,
      cursorminheight:32,
      preservenativescrolling:true,
      railoffset:false,
      bouncescroll:true,
      spacebarenabled:true,
      railpadding:{top:0,right:0,left:0,bottom:0},
      disableoutline:true,
      horizrailenabled:true,
      railalign:"right",
      railvalign:"bottom",
      enabletranslate3d:true,
      enablemousewheel:true,
      enablekeyboard:true,
      smoothscroll:true,
      sensitiverail:true,
      enablemouselockapi:true,
//      cursormaxheight:false,
      cursorfixedheight:false,      
      directionlockdeadzone:6,
      hidecursordelay:400,
      nativeparentscrolling:true,
      enablescrollonselection:true,
      overflowx:true,
      overflowy:true,
      cursordragspeed:0.3,
      rtlmode:false,
      cursordragontouch:false
  }
  
  var browserdetected = false;
  
  var getBrowserDetection = function() {
  
    if (browserdetected) return browserdetected;
  
    var domtest = document.createElement('DIV');

    var d = {};
    
		d.haspointerlock = "pointerLockElement" in document || "mozPointerLockElement" in document || "webkitPointerLockElement" in document;
		
    d.isopera = ("opera" in window);
    d.isopera12 = (d.isopera&&("getUserMedia" in navigator));
    
    d.isie = (("all" in document) && ("attachEvent" in domtest) && !d.isopera);
    d.isieold = (d.isie && !("msInterpolationMode" in domtest.style));  // IE6 and older
    d.isie7 = d.isie&&!d.isieold&&(!("documentMode" in document)||(document.documentMode==7));
    d.isie8 = d.isie&&("documentMode" in document)&&(document.documentMode==8);
    d.isie9 = d.isie&&("performance" in window)&&(document.documentMode>=9);
    d.isie10 = d.isie&&("performance" in window)&&(document.documentMode>=10);
    
    d.isie9mobile = /iemobile.9/i.test(navigator.userAgent);  //wp 7.1 mango
    if (d.isie9mobile) d.isie9 = false;
    d.isie7mobile = (!d.isie9mobile&&d.isie7) && /iemobile/i.test(navigator.userAgent);  //wp 7.0
    
    d.ismozilla = ("MozAppearance" in domtest.style);
		
    d.iswebkit = ("WebkitAppearance" in domtest.style);
    
    d.ischrome = ("chrome" in window);
		d.ischrome22 = (d.ischrome&&d.haspointerlock);
    d.ischrome26 = (d.ischrome&&("transition" in domtest.style));  // issue with transform detection (maintain prefix)
    
    d.cantouch = ("ontouchstart" in document.documentElement)||("ontouchstart" in window);  // detection for Chrome Touch Emulation
    d.hasmstouch = (window.navigator.msPointerEnabled||false);  // IE10+ pointer events
		
    d.ismac = /^mac$/i.test(navigator.platform);
    
    d.isios = (d.cantouch && /iphone|ipad|ipod/i.test(navigator.platform));
    d.isios4 = ((d.isios)&&!("seal" in Object));
    
    d.isandroid = (/android/i.test(navigator.userAgent));
    
    d.trstyle = false;
    d.hastransform = false;
    d.hastranslate3d = false;
    d.transitionstyle = false;
    d.hastransition = false;
    d.transitionend = false;
    
    var check = ['transform','msTransform','webkitTransform','MozTransform','OTransform'];
    for(var a=0;a<check.length;a++){
      if (typeof domtest.style[check[a]] != "undefined") {
        d.trstyle = check[a];
        break;
      }
    }
    d.hastransform = (d.trstyle != false);
    if (d.hastransform) {
      domtest.style[d.trstyle] = "translate3d(1px,2px,3px)";
      d.hastranslate3d = /translate3d/.test(domtest.style[d.trstyle]);
    }
    
    d.transitionstyle = false;
    d.prefixstyle = '';
    d.transitionend = false;
    var check = ['transition','webkitTransition','MozTransition','OTransition','OTransition','msTransition','KhtmlTransition'];
    var prefix = ['','-webkit-','-moz-','-o-','-o','-ms-','-khtml-'];
    var evs = ['transitionend','webkitTransitionEnd','transitionend','otransitionend','oTransitionEnd','msTransitionEnd','KhtmlTransitionEnd'];
    for(var a=0;a<check.length;a++) {
      if (check[a] in domtest.style) {
        d.transitionstyle = check[a];
        d.prefixstyle = prefix[a];
        d.transitionend = evs[a];
        break;
      }
    }
    if (d.ischrome26) {  // use always prefix
      d.prefixstyle = prefix[1];
    }
    
    d.hastransition = (d.transitionstyle);
    
    function detectCursorGrab() {      
      var lst = ['-moz-grab','-webkit-grab','grab'];
      if ((d.ischrome&&!d.ischrome22)||d.isie) lst=[];  // force setting for IE returns false positive and chrome cursor bug
      for(var a=0;a<lst.length;a++) {
        var p = lst[a];
        domtest.style['cursor']=p;
        if (domtest.style['cursor']==p) return p;
      }
      return 'url(http://www.google.com/intl/en_ALL/mapfiles/openhand.cur),n-resize';  // thank you google for custom cursor!
    }
    d.cursorgrabvalue = detectCursorGrab();

    d.hasmousecapture = ("setCapture" in domtest);
    
    d.hasMutationObserver = (clsMutationObserver !== false);
    
    domtest = null;  //memory released

    browserdetected = d;
    
    return d;  
  }
  
  var NiceScrollClass = function(myopt,me) {

    var self = this;

    this.version = '3.4.0';
    this.name = 'nicescroll';
    
    this.me = me;
    
    this.opt = {
      doc:$("body"),
      win:false
    };
    
    $.extend(this.opt,_globaloptions);
    
// Options for internal use
    this.opt.snapbackspeed = 80;
    
    if (myopt||false) {
      for(var a in self.opt) {
        if (typeof myopt[a] != "undefined") self.opt[a] = myopt[a];
      }
    }
    
    this.doc = self.opt.doc;
    this.iddoc = (this.doc&&this.doc[0])?this.doc[0].id||'':'';    
    this.ispage = /BODY|HTML/.test((self.opt.win)?self.opt.win[0].nodeName:this.doc[0].nodeName);
    this.haswrapper = (self.opt.win!==false);
    this.win = self.opt.win||(this.ispage?$(window):this.doc);
    this.docscroll = (this.ispage&&!this.haswrapper)?$(window):this.win;
    this.body = $("body");
    this.viewport = false;
    
    this.isfixed = false;
    
    this.iframe = false;
    this.isiframe = ((this.doc[0].nodeName == 'IFRAME') && (this.win[0].nodeName == 'IFRAME'));
    
    this.istextarea = (this.win[0].nodeName == 'TEXTAREA');
    
    this.forcescreen = false; //force to use screen position on events

    this.canshowonmouseevent = (self.opt.autohidemode!="scroll");
    
// Events jump table    
    this.onmousedown = false;
    this.onmouseup = false;
    this.onmousemove = false;
    this.onmousewheel = false;
    this.onkeypress = false;
    this.ongesturezoom = false;
    this.onclick = false;
    
// Nicescroll custom events
    this.onscrollstart = false;
    this.onscrollend = false;
    this.onscrollcancel = false;    
    
    this.onzoomin = false;
    this.onzoomout = false;
    
// Let's start!  
    this.view = false;
    this.page = false;
    
    this.scroll = {x:0,y:0};
    this.scrollratio = {x:0,y:0};    
    this.cursorheight = 20;
    this.scrollvaluemax = 0;
    
    this.checkrtlmode = false;
    
    this.scrollrunning = false;
    
    this.scrollmom = false;
    
    this.observer = false;
    this.observerremover = false;  // observer on parent for remove detection
    
    do {
      this.id = "ascrail"+(ascrailcounter++);
    } while (document.getElementById(this.id));
    
    this.rail = false;
    this.cursor = false;
    this.cursorfreezed = false;  
    this.selectiondrag = false;
    
    this.zoom = false;
    this.zoomactive = false;
    
    this.hasfocus = false;
    this.hasmousefocus = false;
    
    this.visibility = true;
    this.locked = false;
    this.hidden = false; // rails always hidden
    this.cursoractive = true; // user can interact with cursors
    
    this.overflowx = self.opt.overflowx;
    this.overflowy = self.opt.overflowy;
    
    this.nativescrollingarea = false;
    this.checkarea = 0;
    
    this.events = [];  // event list for unbind
    
    this.saved = {};
    
    this.delaylist = {};
    this.synclist = {};
    
    this.lastdeltax = 0;
    this.lastdeltay = 0;
    
    this.detected = getBrowserDetection(); 
    
    var cap = $.extend({},this.detected);
 
    this.canhwscroll = (cap.hastransform&&self.opt.hwacceleration);
    this.ishwscroll = (this.canhwscroll&&self.haswrapper);
    
    this.istouchcapable = false;  // desktop devices with touch screen support
    
//## Check Chrome desktop with touch support
    if (cap.cantouch&&cap.ischrome&&!cap.isios&&!cap.isandroid) {
      this.istouchcapable = true;
      cap.cantouch = false;  // parse normal desktop events
    }    

//## Firefox 18 nightly build (desktop) false positive (or desktop with touch support)
    if (cap.cantouch&&cap.ismozilla&&!cap.isios) {
      this.istouchcapable = true;
      cap.cantouch = false;  // parse normal desktop events
    }    
    
//## disable MouseLock API on user request

    if (!self.opt.enablemouselockapi) {
      cap.hasmousecapture = false;
      cap.haspointerlock = false;
    }
    
    this.delayed = function(name,fn,tm,lazy) {
      var dd = self.delaylist[name];
      var nw = (new Date()).getTime();
      if (!lazy&&dd&&dd.tt) return false;
      if (dd&&dd.tt) clearTimeout(dd.tt);
      if (dd&&dd.last+tm>nw&&!dd.tt) {      
        self.delaylist[name] = {
          last:nw+tm,
          tt:setTimeout(function(){self.delaylist[name].tt=0;fn.call();},tm)
        }
      }
      else if (!dd||!dd.tt) {
        self.delaylist[name] = {
          last:nw,
          tt:0
        }
        setTimeout(function(){fn.call();},0);
      }
    };
    
    this.debounced = function(name,fn,tm) {
      var dd = self.delaylist[name];
      var nw = (new Date()).getTime();      
      self.delaylist[name] = fn;
      if (!dd) {        
        setTimeout(function(){var fn=self.delaylist[name];self.delaylist[name]=false;fn.call();},tm);
      }
    }
    
    this.synched = function(name,fn) {
    
      function requestSync() {
        if (self.onsync) return;
        setAnimationFrame(function(){
          self.onsync = false;
          for(name in self.synclist){
            var fn = self.synclist[name];
            if (fn) fn.call(self);
            self.synclist[name] = false;
          }
        });
        self.onsync = true;
      };    
    
      self.synclist[name] = fn;
      requestSync();
      return name;
    };
    
    this.unsynched = function(name) {
      if (self.synclist[name]) self.synclist[name] = false;
    }
    
    this.css = function(el,pars) {  // save & set
      for(var n in pars) {
        self.saved.css.push([el,n,el.css(n)]);
        el.css(n,pars[n]);
      }
    };
    
    this.scrollTop = function(val) {
      return (typeof val == "undefined") ? self.getScrollTop() : self.setScrollTop(val);
    };

    this.scrollLeft = function(val) {
      return (typeof val == "undefined") ? self.getScrollLeft() : self.setScrollLeft(val);
    };
    
// derived by by Dan Pupius www.pupius.net
    BezierClass = function(st,ed,spd,p1,p2,p3,p4) {
      this.st = st;
      this.ed = ed;
      this.spd = spd;
      
      this.p1 = p1||0;
      this.p2 = p2||1;
      this.p3 = p3||0;
      this.p4 = p4||1;
      
      this.ts = (new Date()).getTime();
      this.df = this.ed-this.st;
    };
    BezierClass.prototype = {
      B2:function(t){ return 3*t*t*(1-t) },
      B3:function(t){ return 3*t*(1-t)*(1-t) },
      B4:function(t){ return (1-t)*(1-t)*(1-t) },
      getNow:function(){
        var nw = (new Date()).getTime();
        var pc = 1-((nw-this.ts)/this.spd);
        var bz = this.B2(pc) + this.B3(pc) + this.B4(pc);
        return (pc<0) ? this.ed : this.st+Math.round(this.df*bz);
      },
      update:function(ed,spd){
        this.st = this.getNow();
        this.ed = ed;
        this.spd = spd;
        this.ts = (new Date()).getTime();
        this.df = this.ed-this.st;
        return this;
      }
    };
    
    if (this.ishwscroll) {  
    // hw accelerated scroll
      this.doc.translate = {x:0,y:0,tx:"0px",ty:"0px"};
      
      //this one can help to enable hw accel on ios6 http://indiegamr.com/ios6-html-hardware-acceleration-changes-and-how-to-fix-them/
      if (cap.hastranslate3d&&cap.isios) this.doc.css("-webkit-backface-visibility","hidden");  // prevent flickering http://stackoverflow.com/questions/3461441/      
      
      //derived from http://stackoverflow.com/questions/11236090/
      function getMatrixValues() {
        var tr = self.doc.css(cap.trstyle);
        if (tr&&(tr.substr(0,6)=="matrix")) {
          return tr.replace(/^.*\((.*)\)$/g, "$1").replace(/px/g,'').split(/, +/);
        }
        return false;
      }
      
      this.getScrollTop = function(last) {
        if (!last) {
          var mtx = getMatrixValues();
          if (mtx) return (mtx.length==16) ? -mtx[13] : -mtx[5];  //matrix3d 16 on IE10
          if (self.timerscroll&&self.timerscroll.bz) return self.timerscroll.bz.getNow();
        }
        return self.doc.translate.y;
      };

      this.getScrollLeft = function(last) {
        if (!last) {
          var mtx = getMatrixValues();          
          if (mtx) return (mtx.length==16) ? -mtx[12] : -mtx[4];  //matrix3d 16 on IE10
          if (self.timerscroll&&self.timerscroll.bh) return self.timerscroll.bh.getNow();
        }
        return self.doc.translate.x;
      };
      
      if (document.createEvent) {
        this.notifyScrollEvent = function(el) {
          var e = document.createEvent("UIEvents");
          e.initUIEvent("scroll", false, true, window, 1);
          el.dispatchEvent(e);
        };
      }
      else if (document.fireEvent) {
        this.notifyScrollEvent = function(el) {
          var e = document.createEventObject();
          el.fireEvent("onscroll");
          e.cancelBubble = true; 
        };
      }
      else {
        this.notifyScrollEvent = function(el,add) {}; //NOPE
      }
      
      if (cap.hastranslate3d&&self.opt.enabletranslate3d) {
        this.setScrollTop = function(val,silent) {
          self.doc.translate.y = val;
          self.doc.translate.ty = (val*-1)+"px";
          self.doc.css(cap.trstyle,"translate3d("+self.doc.translate.tx+","+self.doc.translate.ty+",0px)");          
          if (!silent) self.notifyScrollEvent(self.win[0]);
        };
        this.setScrollLeft = function(val,silent) {          
          self.doc.translate.x = val;
          self.doc.translate.tx = (val*-1)+"px";
          self.doc.css(cap.trstyle,"translate3d("+self.doc.translate.tx+","+self.doc.translate.ty+",0px)");          
          if (!silent) self.notifyScrollEvent(self.win[0]);
        };
      } else {
        this.setScrollTop = function(val,silent) {
          self.doc.translate.y = val;
          self.doc.translate.ty = (val*-1)+"px";
          self.doc.css(cap.trstyle,"translate("+self.doc.translate.tx+","+self.doc.translate.ty+")");
          if (!silent) self.notifyScrollEvent(self.win[0]);          
        };
        this.setScrollLeft = function(val,silent) {        
          self.doc.translate.x = val;
          self.doc.translate.tx = (val*-1)+"px";
          self.doc.css(cap.trstyle,"translate("+self.doc.translate.tx+","+self.doc.translate.ty+")");
          if (!silent) self.notifyScrollEvent(self.win[0]);
        };
      }
    } else {
    // native scroll
      this.getScrollTop = function() {
        return self.docscroll.scrollTop();
      };
      this.setScrollTop = function(val) {        
        return self.docscroll.scrollTop(val);
      };
      this.getScrollLeft = function() {
        return self.docscroll.scrollLeft();
      };
      this.setScrollLeft = function(val) {
        return self.docscroll.scrollLeft(val);
      };
    }
    
    this.getTarget = function(e) {
      if (!e) return false;
      if (e.target) return e.target;
      if (e.srcElement) return e.srcElement;
      return false;
    };
    
    this.hasParent = function(e,id) {
      if (!e) return false;
      var el = e.target||e.srcElement||e||false;
      while (el && el.id != id) {
        el = el.parentNode||false;
      }
      return (el!==false);
    };
    
    function getZIndex() {
      var dom = self.win;
      if ("zIndex" in dom) return dom.zIndex();  // use jQuery UI method when available
      while (dom.length>0) {        
        if (dom[0].nodeType==9) return false;
        var zi = dom.css('zIndex');        
        if (!isNaN(zi)&&zi!=0) return parseInt(zi);
        dom = dom.parent();
      }
      return false;
    };
    
//inspired by http://forum.jquery.com/topic/width-includes-border-width-when-set-to-thin-medium-thick-in-ie
    var _convertBorderWidth = {"thin":1,"medium":3,"thick":5};
    function getWidthToPixel(dom,prop,chkheight) {
      var wd = dom.css(prop);
      var px = parseFloat(wd);
      if (isNaN(px)) {
        px = _convertBorderWidth[wd]||0;
        var brd = (px==3) ? ((chkheight)?(self.win.outerHeight() - self.win.innerHeight()):(self.win.outerWidth() - self.win.innerWidth())) : 1; //DON'T TRUST CSS
        if (self.isie8&&px) px+=1;
        return (brd) ? px : 0; 
      }
      return px;
    };
    
    this.getOffset = function() {
      if (self.isfixed) return {top:parseFloat(self.win.css('top')),left:parseFloat(self.win.css('left'))};
      if (!self.viewport) return self.win.offset();
      var ww = self.win.offset();
      var vp = self.viewport.offset();
      return {top:ww.top-vp.top+self.viewport.scrollTop(),left:ww.left-vp.left+self.viewport.scrollLeft()};
    };
    
    this.updateScrollBar = function(len) {
      if (self.ishwscroll) {
        self.rail.css({height:self.win.innerHeight()});
        if (self.railh) self.railh.css({width:self.win.innerWidth()});
      } else {
        var wpos = self.getOffset();
        var pos = {top:wpos.top,left:wpos.left};
        pos.top+= getWidthToPixel(self.win,'border-top-width',true);
        var brd = (self.win.outerWidth() - self.win.innerWidth())/2;
        pos.left+= (self.rail.align) ? self.win.outerWidth() - getWidthToPixel(self.win,'border-right-width') - self.rail.width : getWidthToPixel(self.win,'border-left-width');
        
        var off = self.opt.railoffset;
        if (off) {
          if (off.top) pos.top+=off.top;
          if (self.rail.align&&off.left) pos.left+=off.left;
        }
        
				if (!self.locked) self.rail.css({top:pos.top,left:pos.left,height:(len)?len.h:self.win.innerHeight()});
				
				if (self.zoom) {				  
				  self.zoom.css({top:pos.top+1,left:(self.rail.align==1) ? pos.left-20 : pos.left+self.rail.width+4});
			  }
				
				if (self.railh&&!self.locked) {
					var pos = {top:wpos.top,left:wpos.left};
					var y = (self.railh.align) ? pos.top + getWidthToPixel(self.win,'border-top-width',true) + self.win.innerHeight() - self.railh.height : pos.top + getWidthToPixel(self.win,'border-top-width',true);
					var x = pos.left + getWidthToPixel(self.win,'border-left-width');
					self.railh.css({top:y,left:x,width:self.railh.width});
				}
		
				
      }
    };
    
    this.doRailClick = function(e,dbl,hr) {

      var fn,pg,cur,pos;
      
//      if (self.rail.drag&&self.rail.drag.pt!=1) return;
      if (self.locked) return;
//      if (self.rail.drag) return;

//      self.cancelScroll();       
      
      self.cancelEvent(e);
      
      if (dbl) {
        fn = (hr) ? self.doScrollLeft : self.doScrollTop;
        cur = (hr) ? ((e.pageX - self.railh.offset().left - (self.cursorwidth/2)) * self.scrollratio.x) : ((e.pageY - self.rail.offset().top - (self.cursorheight/2)) * self.scrollratio.y);
        fn(cur);
      } else {
//        console.log(e.pageY);
        fn = (hr) ? self.doScrollLeftBy : self.doScrollBy;
        cur = (hr) ? self.scroll.x : self.scroll.y;
        pos = (hr) ? e.pageX - self.railh.offset().left : e.pageY - self.rail.offset().top;
        pg = (hr) ? self.view.w : self.view.h;        
        (cur>=pos) ? fn(pg) : fn(-pg);
      }
    
    }
    
    self.hasanimationframe = (setAnimationFrame);
    self.hascancelanimationframe = (clearAnimationFrame);
    
    if (!self.hasanimationframe) {
      setAnimationFrame=function(fn){return setTimeout(fn,15-Math.floor((+new Date)/1000)%16)}; // 1000/60)};
      clearAnimationFrame=clearInterval;
    } 
    else if (!self.hascancelanimationframe) clearAnimationFrame=function(){self.cancelAnimationFrame=true};
    
    this.init = function() {

      self.saved.css = [];
      
      if (cap.isie7mobile) return true; // SORRY, DO NOT WORK!
      
      if (cap.hasmstouch) self.css((self.ispage)?$("html"):self.win,{'-ms-touch-action':'none'});
      
      self.zindex = "auto";
      if (!self.ispage&&self.opt.zindex=="auto") {
        self.zindex = getZIndex()||"auto";
      } else {
        self.zindex = self.opt.zindex;
      }
      
      if (!self.ispage&&self.zindex!="auto") {
        if (self.zindex>globalmaxzindex) globalmaxzindex=self.zindex;
      }
      
      if (self.isie&&self.zindex==0&&self.opt.zindex=="auto") {  // fix IE auto == 0
        self.zindex="auto";
      }
      
/*      
      self.ispage = true;
      self.haswrapper = true;
//      self.win = $(window);
      self.docscroll = $("body");
//      self.doc = $("body");
*/
      
      if (!self.ispage || (!cap.cantouch && !cap.isieold && !cap.isie9mobile)) {
      
        var cont = self.docscroll;
        if (self.ispage) cont = (self.haswrapper)?self.win:self.doc;
        
        if (!cap.isie9mobile) self.css(cont,{'overflow-y':'hidden'});      
        
        if (self.ispage&&cap.isie7) {
          if (self.doc[0].nodeName=='BODY') self.css($("html"),{'overflow-y':'hidden'});  //IE7 double scrollbar issue
          else if (self.doc[0].nodeName=='HTML') self.css($("body"),{'overflow-y':'hidden'});  //IE7 double scrollbar issue
        }
        
        if (cap.isios&&!self.ispage&&!self.haswrapper) self.css($("body"),{"-webkit-overflow-scrolling":"touch"});  //force hw acceleration
        
        var cursor = $(document.createElement('div'));
        cursor.css({
          position:"relative",top:0,"float":"right",width:self.opt.cursorwidth,height:"0px",
          'background-color':self.opt.cursorcolor,
          border:self.opt.cursorborder,
          'background-clip':'padding-box',
          '-webkit-border-radius':self.opt.cursorborderradius,
          '-moz-border-radius':self.opt.cursorborderradius,
          'border-radius':self.opt.cursorborderradius
        });   
        
        cursor.hborder = parseFloat(cursor.outerHeight() - cursor.innerHeight());        
        self.cursor = cursor;        
        
        var rail = $(document.createElement('div'));
        rail.attr('id',self.id);
        rail.addClass('nicescroll-rails');
        
        var v,a,kp = ["left","right"];  //"top","bottom"
        for(var n in kp) {
          a=kp[n];
          v = self.opt.railpadding[a];
          (v) ? rail.css("padding-"+a,v+"px") : self.opt.railpadding[a] = 0;
        }
        
        rail.append(cursor);
        
        rail.width = Math.max(parseFloat(self.opt.cursorwidth),cursor.outerWidth()) + self.opt.railpadding['left'] + self.opt.railpadding['right'];
        rail.css({width:rail.width+"px",'zIndex':self.zindex,"background":self.opt.background,cursor:"default"});        
        
        rail.visibility = true;
        rail.scrollable = true;
        
        rail.align = (self.opt.railalign=="left") ? 0 : 1;
        
        self.rail = rail;
        
        self.rail.drag = false;
        
        var zoom = false;
        if (self.opt.boxzoom&&!self.ispage&&!cap.isieold) {
          zoom = document.createElement('div');          
          self.bind(zoom,"click",self.doZoom);
          self.zoom = $(zoom);
          self.zoom.css({"cursor":"pointer",'z-index':self.zindex,'backgroundImage':'url('+scriptpath+'zoomico.png)','height':18,'width':18,'backgroundPosition':'0px 0px'});
          if (self.opt.dblclickzoom) self.bind(self.win,"dblclick",self.doZoom);
          if (cap.cantouch&&self.opt.gesturezoom) {
            self.ongesturezoom = function(e) {
              if (e.scale>1.5) self.doZoomIn(e);
              if (e.scale<0.8) self.doZoomOut(e);
              return self.cancelEvent(e);
            };
            self.bind(self.win,"gestureend",self.ongesturezoom);             
          }
        }
        
// init HORIZ

        self.railh = false;

        if (self.opt.horizrailenabled) {

          self.css(cont,{'overflow-x':'hidden'});

          var cursor = $(document.createElement('div'));
          cursor.css({
            position:"relative",top:0,height:self.opt.cursorwidth,width:"0px",
            'background-color':self.opt.cursorcolor,
            border:self.opt.cursorborder,
            'background-clip':'padding-box',
            '-webkit-border-radius':self.opt.cursorborderradius,
            '-moz-border-radius':self.opt.cursorborderradius,
            'border-radius':self.opt.cursorborderradius
          });   
          
          cursor.wborder = parseFloat(cursor.outerWidth() - cursor.innerWidth());
          self.cursorh = cursor;
          
          var railh = $(document.createElement('div'));
          railh.attr('id',self.id+'-hr');
          railh.addClass('nicescroll-rails');
          railh.height = Math.max(parseFloat(self.opt.cursorwidth),cursor.outerHeight());
          railh.css({height:railh.height+"px",'zIndex':self.zindex,"background":self.opt.background});
          
          railh.append(cursor);
          
          railh.visibility = true;
          railh.scrollable = true;
          
          railh.align = (self.opt.railvalign=="top") ? 0 : 1;
          
          self.railh = railh;
          
          self.railh.drag = false;
          
        }
        
//        
        
        if (self.ispage) {
          rail.css({position:"fixed",top:"0px",height:"100%"});
          (rail.align) ? rail.css({right:"0px"}) : rail.css({left:"0px"});
          self.body.append(rail);
          if (self.railh) {
            railh.css({position:"fixed",left:"0px",width:"100%"});
            (railh.align) ? railh.css({bottom:"0px"}) : railh.css({top:"0px"});
            self.body.append(railh);
          }
        } else {          
          if (self.ishwscroll) {
            if (self.win.css('position')=='static') self.css(self.win,{'position':'relative'});
            var bd = (self.win[0].nodeName == 'HTML') ? self.body : self.win;
            if (self.zoom) {
              self.zoom.css({position:"absolute",top:1,right:0,"margin-right":rail.width+4});
              bd.append(self.zoom);
            }
            rail.css({position:"absolute",top:0});
            (rail.align) ? rail.css({right:0}) : rail.css({left:0});
            bd.append(rail);
            if (railh) {
              railh.css({position:"absolute",left:0,bottom:0});
              (railh.align) ? railh.css({bottom:0}) : railh.css({top:0});
              bd.append(railh);
            }
          } else {
            self.isfixed = (self.win.css("position")=="fixed");
            var rlpos = (self.isfixed) ? "fixed" : "absolute";
            
            if (!self.isfixed) self.viewport = self.getViewport(self.win[0]);
            if (self.viewport) {
              self.body = self.viewport;              
              if ((/relative|absolute/.test(self.viewport.css("position")))==false) self.css(self.viewport,{"position":"relative"});
            }            
            
            rail.css({position:rlpos});
            if (self.zoom) self.zoom.css({position:rlpos});
            self.updateScrollBar();
            self.body.append(rail);
            if (self.zoom) self.body.append(self.zoom);
            if (self.railh) {
              railh.css({position:rlpos});
              self.body.append(railh);           
            }
          }
          
          if (cap.isios) self.css(self.win,{'-webkit-tap-highlight-color':'rgba(0,0,0,0)','-webkit-touch-callout':'none'});  // prevent grey layer on click
          
					if (cap.isie&&self.opt.disableoutline) self.win.attr("hideFocus","true");  // IE, prevent dotted rectangle on focused div
					if (cap.iswebkit&&self.opt.disableoutline) self.win.css({"outline":"none"});
          
        }
        
        if (self.opt.autohidemode===false) {
          self.autohidedom = false;
          self.rail.css({opacity:self.opt.cursoropacitymax});          
          if (self.railh) self.railh.css({opacity:self.opt.cursoropacitymax});
        }
        else if (self.opt.autohidemode===true) {
          self.autohidedom = $().add(self.rail);          
          if (cap.isie8) self.autohidedom=self.autohidedom.add(self.cursor);
          if (self.railh) self.autohidedom=self.autohidedom.add(self.railh);
          if (self.railh&&cap.isie8) self.autohidedom=self.autohidedom.add(self.cursorh);
        }
        else if (self.opt.autohidemode=="scroll") {
          self.autohidedom = $().add(self.rail);
          if (self.railh) self.autohidedom=self.autohidedom.add(self.railh);
        }
        else if (self.opt.autohidemode=="cursor") {
          self.autohidedom = $().add(self.cursor);
          if (self.railh) self.autohidedom=self.autohidedom.add(self.cursorh);
        }
        else if (self.opt.autohidemode=="hidden") {
          self.autohidedom = false;
          self.hide();
          self.locked = false;
        }
        
        if (cap.isie9mobile) {

          self.scrollmom = new ScrollMomentumClass2D(self);        

          /*
          var trace = function(msg) {
            var db = $("#debug");
            if (isNaN(msg)&&(typeof msg != "string")) {
              var x = [];
              for(var a in msg) {
                x.push(a+":"+msg[a]);
              }
              msg ="{"+x.join(",")+"}";
            }
            if (db.children().length>0) {
              db.children().eq(0).before("<div>"+msg+"</div>");
            } else {
              db.append("<div>"+msg+"</div>");
            }
          }
          window.onerror = function(msg,url,ln) {
            trace("ERR: "+msg+" at "+ln);
          }
*/          
  
          self.onmangotouch = function(e) {
            var py = self.getScrollTop();
            var px = self.getScrollLeft();
            
            if ((py == self.scrollmom.lastscrolly)&&(px == self.scrollmom.lastscrollx)) return true;
//            $("#debug").html('DRAG:'+py);

            var dfy = py-self.mangotouch.sy;
            var dfx = px-self.mangotouch.sx;            
            var df = Math.round(Math.sqrt(Math.pow(dfx,2)+Math.pow(dfy,2)));            
            if (df==0) return;
            
            var dry = (dfy<0)?-1:1;
            var drx = (dfx<0)?-1:1;
            
            var tm = +new Date();
            if (self.mangotouch.lazy) clearTimeout(self.mangotouch.lazy);
            
            if (((tm-self.mangotouch.tm)>80)||(self.mangotouch.dry!=dry)||(self.mangotouch.drx!=drx)) {
//              trace('RESET+'+(tm-self.mangotouch.tm));
              self.scrollmom.stop();
              self.scrollmom.reset(px,py);
              self.mangotouch.sy = py;
              self.mangotouch.ly = py;
              self.mangotouch.sx = px;
              self.mangotouch.lx = px;
              self.mangotouch.dry = dry;
              self.mangotouch.drx = drx;
              self.mangotouch.tm = tm;
            } else {
              
              self.scrollmom.stop();
              self.scrollmom.update(self.mangotouch.sx-dfx,self.mangotouch.sy-dfy);
              var gap = tm - self.mangotouch.tm;              
              self.mangotouch.tm = tm;
              
//              trace('MOVE:'+df+" - "+gap);
              
              var ds = Math.max(Math.abs(self.mangotouch.ly-py),Math.abs(self.mangotouch.lx-px));
              self.mangotouch.ly = py;
              self.mangotouch.lx = px;
              
              if (ds>2) {
                self.mangotouch.lazy = setTimeout(function(){
//                  trace('END:'+ds+'+'+gap);                  
                  self.mangotouch.lazy = false;
                  self.mangotouch.dry = 0;
                  self.mangotouch.drx = 0;
                  self.mangotouch.tm = 0;                  
                  self.scrollmom.doMomentum(30);
                },100);
              }
            }
          }
          
          var top = self.getScrollTop();
          var lef = self.getScrollLeft();
          self.mangotouch = {sy:top,ly:top,dry:0,sx:lef,lx:lef,drx:0,lazy:false,tm:0};
          
          self.bind(self.docscroll,"scroll",self.onmangotouch);
        
        } else {
        
          if (cap.cantouch||self.istouchcapable||self.opt.touchbehavior||cap.hasmstouch) {
          
            self.scrollmom = new ScrollMomentumClass2D(self);
          
            self.ontouchstart = function(e) {
              if (e.pointerType&&e.pointerType!=2) return false;
              
              if (!self.locked) {
              
                if (cap.hasmstouch) {
                  var tg = (e.target) ? e.target : false;
                  while (tg) {
                    var nc = $(tg).getNiceScroll();
                    if ((nc.length>0)&&(nc[0].me == self.me)) break;
                    if (nc.length>0) return false;
                    if ((tg.nodeName=='DIV')&&(tg.id==self.id)) break;
                    tg = (tg.parentNode) ? tg.parentNode : false;
                  }
                }
              
                self.cancelScroll();
                
                var tg = self.getTarget(e);
                
                if (tg) {
                  var skp = (/INPUT/i.test(tg.nodeName))&&(/range/i.test(tg.type));
                  if (skp) return self.stopPropagation(e);
                }
                
                if (!("clientX" in e) && ("changedTouches" in e)) {
                  e.clientX = e.changedTouches[0].clientX;
                  e.clientY = e.changedTouches[0].clientY;
                }
                
                if (self.forcescreen) {
                  var le = e;
                  var e = {"original":(e.original)?e.original:e};
                  e.clientX = le.screenX;
                  e.clientY = le.screenY;    
                }
                
                self.rail.drag = {x:e.clientX,y:e.clientY,sx:self.scroll.x,sy:self.scroll.y,st:self.getScrollTop(),sl:self.getScrollLeft(),pt:2,dl:false};
                
                if (self.ispage||!self.opt.directionlockdeadzone) {
                  self.rail.drag.dl = "f";
                } else {
                
                  var view = {
                    w:$(window).width(),
                    h:$(window).height()
                  };
                  
                  var page = {
                    w:Math.max(document.body.scrollWidth,document.documentElement.scrollWidth),
                    h:Math.max(document.body.scrollHeight,document.documentElement.scrollHeight)
                  }
                  
                  var maxh = Math.max(0,page.h - view.h);
                  var maxw = Math.max(0,page.w - view.w);                
                
                  if (!self.rail.scrollable&&self.railh.scrollable) self.rail.drag.ck = (maxh>0) ? "v" : false;
                  else if (self.rail.scrollable&&!self.railh.scrollable) self.rail.drag.ck = (maxw>0) ? "h" : false;
                  else self.rail.drag.ck = false;
                  if (!self.rail.drag.ck) self.rail.drag.dl = "f";
                }
                
                if (self.opt.touchbehavior&&self.isiframe&&cap.isie) {
                  var wp = self.win.position();
                  self.rail.drag.x+=wp.left;
                  self.rail.drag.y+=wp.top;
                }
                
                self.hasmoving = false;
                self.lastmouseup = false;
                self.scrollmom.reset(e.clientX,e.clientY);
                if (!cap.cantouch&&!this.istouchcapable&&!cap.hasmstouch) {
                  
                  var ip = (tg)?/INPUT|SELECT|TEXTAREA/i.test(tg.nodeName):false;
                  if (!ip) {
                    if (!self.ispage&&cap.hasmousecapture) tg.setCapture();
                    return self.cancelEvent(e);
                  }
                  if (/SUBMIT|CANCEL|BUTTON/i.test($(tg).attr('type'))) {
                    pc = {"tg":tg,"click":false};
                    self.preventclick = pc;
                  }
                  
                }
              }
              
            };
            
            self.ontouchend = function(e) {
              if (e.pointerType&&e.pointerType!=2) return false;
              if (self.rail.drag&&(self.rail.drag.pt==2)) {
                self.scrollmom.doMomentum();
                self.rail.drag = false;
                if (self.hasmoving) {
                  self.hasmoving = false;
                  self.lastmouseup = true;
                  self.hideCursor();
                  if (cap.hasmousecapture) document.releaseCapture();
                  if (!cap.cantouch) return self.cancelEvent(e);
                }                            
              }                        
              
            };
            
            var moveneedoffset = (self.opt.touchbehavior&&self.isiframe&&!cap.hasmousecapture);
            
            self.ontouchmove = function(e,byiframe) {
              
              if (e.pointerType&&e.pointerType!=2) return false;
    
              if (self.rail.drag&&(self.rail.drag.pt==2)) {
                if (cap.cantouch&&(typeof e.original == "undefined")) return true;  // prevent ios "ghost" events by clickable elements
              
                self.hasmoving = true;

                if (self.preventclick&&!self.preventclick.click) {
                  self.preventclick.click = self.preventclick.tg.onclick||false;                
                  self.preventclick.tg.onclick = self.onpreventclick;
                }

                var ev = $.extend({"original":e},e);
                e = ev;
                
                if (("changedTouches" in e)) {
                  e.clientX = e.changedTouches[0].clientX;
                  e.clientY = e.changedTouches[0].clientY;
                }                
                
                if (self.forcescreen) {
                  var le = e;
                  var e = {"original":(e.original)?e.original:e};
                  e.clientX = le.screenX;
                  e.clientY = le.screenY;      
                }
                
                var ofx = ofy = 0;
                
                if (moveneedoffset&&!byiframe) {
                  var wp = self.win.position();
                  ofx=-wp.left;
                  ofy=-wp.top;
                }                
                
                var fy = e.clientY + ofy;
                var my = (fy-self.rail.drag.y);
                var fx = e.clientX + ofx;
                var mx = (fx-self.rail.drag.x);
                
                var ny = self.rail.drag.st-my;
                
                if (self.ishwscroll&&self.opt.bouncescroll) {
                  if (ny<0) {
                    ny = Math.round(ny/2);
//                    fy = 0;
                  }
                  else if (ny>self.page.maxh) {
                    ny = self.page.maxh+Math.round((ny-self.page.maxh)/2);
//                    fy = 0;
                  }
                } else {
                  if (ny<0) {ny=0;fy=0}
                  if (ny>self.page.maxh) {ny=self.page.maxh;fy=0}
                }
                  
                if (self.railh&&self.railh.scrollable) {
                  var nx = self.rail.drag.sl-mx;
                  
                  if (self.ishwscroll&&self.opt.bouncescroll) {                  
                    if (nx<0) {
                      nx = Math.round(nx/2);
//                      fx = 0;
                    }
                    else if (nx>self.page.maxw) {
                      nx = self.page.maxw+Math.round((nx-self.page.maxw)/2);
//                      fx = 0;
                    }
                  } else {
                    if (nx<0) {nx=0;fx=0}
                    if (nx>self.page.maxw) {nx=self.page.maxw;fx=0}
                  }
                
                }
                
                var grabbed = false;
                if (self.rail.drag.dl) {
                  grabbed = true;
                  if (self.rail.drag.dl=="v") nx = self.rail.drag.sl;
                  else if (self.rail.drag.dl=="h") ny = self.rail.drag.st;                  
                } else {
                  var ay = Math.abs(my);
                  var ax = Math.abs(mx);
                  var dz = self.opt.directionlockdeadzone;
                  if (self.rail.drag.ck=="v") {    
                    if (ay>dz&&(ax<=(ay*0.3))) {
                      self.rail.drag = false;                      
                      return true;
                    }
                    else if (ax>dz) {
                      self.rail.drag.dl="f";                      
                      $("body").scrollTop($("body").scrollTop());  // stop iOS native scrolling (when active javascript has blocked)
                    }
                  }
                  else if (self.rail.drag.ck=="h") {
                    if (ax>dz&&(ay<=(az*0.3))) {
                      self.rail.drag = false;                      
                      return true;
                    }
                    else if (ay>dz) {                      
                      self.rail.drag.dl="f";
                      $("body").scrollLeft($("body").scrollLeft());  // stop iOS native scrolling (when active javascript has blocked)
                    }
                  }  
                }
                
                self.synched("touchmove",function(){
                  if (self.rail.drag&&(self.rail.drag.pt==2)) {
                    if (self.prepareTransition) self.prepareTransition(0);
                    if (self.rail.scrollable) self.setScrollTop(ny);
                    self.scrollmom.update(fx,fy);
                    if (self.railh&&self.railh.scrollable) {
                      self.setScrollLeft(nx);
                      self.showCursor(ny,nx);
                    } else {
                      self.showCursor(ny);
                    }
                    if (cap.isie10) document.selection.clear();
                  }
                });
                
                if (cap.ischrome&&self.istouchcapable) grabbed=false;  //chrome touch emulation doesn't like!
                if (grabbed) return self.cancelEvent(e);
              }
              
            };
          
          }
          
          self.onmousedown = function(e,hronly) {    
            if (self.rail.drag&&self.rail.drag.pt!=1) return;
            if (self.locked) return self.cancelEvent(e);            
            self.cancelScroll();              
            self.rail.drag = {x:e.clientX,y:e.clientY,sx:self.scroll.x,sy:self.scroll.y,pt:1,hr:(!!hronly)};
            var tg = self.getTarget(e);
            if (!self.ispage&&cap.hasmousecapture) tg.setCapture();
            if (self.isiframe&&!cap.hasmousecapture) {
              self.saved["csspointerevents"] = self.doc.css("pointer-events");
              self.css(self.doc,{"pointer-events":"none"});
            }
            return self.cancelEvent(e);
          };
          
          self.onmouseup = function(e) {
            if (self.rail.drag) {
              if (cap.hasmousecapture) document.releaseCapture();
              if (self.isiframe&&!cap.hasmousecapture) self.doc.css("pointer-events",self.saved["csspointerevents"]);
              if(self.rail.drag.pt!=1)return;
              self.rail.drag = false;
              //if (!self.rail.active) self.hideCursor();
              return self.cancelEvent(e);
            }
          };        
          
          self.onmousemove = function(e) {
            if (self.rail.drag) {
              if(self.rail.drag.pt!=1)return;
              
              if (cap.ischrome&&e.which==0) return self.onmouseup(e);
              
              self.cursorfreezed = true;
                  
              if (self.rail.drag.hr) {
                self.scroll.x = self.rail.drag.sx + (e.clientX-self.rail.drag.x);
                if (self.scroll.x<0) self.scroll.x=0;
                var mw = self.scrollvaluemaxw;
                if (self.scroll.x>mw) self.scroll.x=mw;
              } else {                
                self.scroll.y = self.rail.drag.sy + (e.clientY-self.rail.drag.y);
                if (self.scroll.y<0) self.scroll.y=0;
                var my = self.scrollvaluemax;
                if (self.scroll.y>my) self.scroll.y=my;
              }
              
              self.synched('mousemove',function(){
                if (self.rail.drag&&(self.rail.drag.pt==1)) {
                  self.showCursor();
                  if (self.rail.drag.hr) self.doScrollLeft(Math.round(self.scroll.x*self.scrollratio.x),self.opt.cursordragspeed);
                  else self.doScrollTop(Math.round(self.scroll.y*self.scrollratio.y),self.opt.cursordragspeed);
                }
              });
              
              return self.cancelEvent(e);
            } 
/*              
            else {
              self.checkarea = true;
            }
*/              
          };          
         
          if (cap.cantouch||self.opt.touchbehavior) {
          
            self.onpreventclick = function(e) {
              if (self.preventclick) {
                self.preventclick.tg.onclick = self.preventclick.click;
                self.preventclick = false;            
                return self.cancelEvent(e);
              }
            }
          
//            self.onmousedown = self.ontouchstart;            
//            self.onmouseup = self.ontouchend;
//            self.onmousemove = self.ontouchmove;

            self.bind(self.win,"mousedown",self.ontouchstart);  // control content dragging

            self.onclick = (cap.isios) ? false : function(e) { 
              if (self.lastmouseup) {
                self.lastmouseup = false;
                return self.cancelEvent(e);
              } else {
                return true;
              }
            }; 
            
            if (self.opt.grabcursorenabled&&cap.cursorgrabvalue) {
              self.css((self.ispage)?self.doc:self.win,{'cursor':cap.cursorgrabvalue});            
              self.css(self.rail,{'cursor':cap.cursorgrabvalue});
            }
            
          } else {

            function checkSelectionScroll(e) {
              if (!self.selectiondrag) return;
              
              if (e) {
                var ww = self.win.outerHeight();
                var df = (e.pageY - self.selectiondrag.top);
                if (df>0&&df<ww) df=0;
                if (df>=ww) df-=ww;
                self.selectiondrag.df = df;                
              }
              if (self.selectiondrag.df==0) return;
              
              var rt = -Math.floor(self.selectiondrag.df/6)*2;              
//              self.doScrollTop(self.getScrollTop(true)+rt);
              self.doScrollBy(rt);
              
              self.debounced("doselectionscroll",function(){checkSelectionScroll()},50);
            }
            
            if ("getSelection" in document) {  // A grade - Major browsers
              self.hasTextSelected = function() {  
                return (document.getSelection().rangeCount>0);
              }
            } 
            else if ("selection" in document) {  //IE9-
              self.hasTextSelected = function() {
                return (document.selection.type != "None");
              }
            } 
            else {
              self.hasTextSelected = function() {  // no support
                return false;
              }
            }            
            
            self.onselectionstart = function(e) {
              if (self.ispage) return;
              self.selectiondrag = self.win.offset();
            }
            self.onselectionend = function(e) {
              self.selectiondrag = false;
            }
            self.onselectiondrag = function(e) {              
              if (!self.selectiondrag) return;
              if (self.hasTextSelected()) self.debounced("selectionscroll",function(){checkSelectionScroll(e)},250);
            }
            
            
          }
          
          if (cap.hasmstouch) {
            self.css(self.rail,{'-ms-touch-action':'none'});
            self.css(self.cursor,{'-ms-touch-action':'none'});
            
            self.bind(self.win,"MSPointerDown",self.ontouchstart);
            self.bind(document,"MSPointerUp",self.ontouchend);
            self.bind(document,"MSPointerMove",self.ontouchmove);
            self.bind(self.cursor,"MSGestureHold",function(e){e.preventDefault()});
            self.bind(self.cursor,"contextmenu",function(e){e.preventDefault()});
          }

          if (this.istouchcapable) {  //desktop with screen touch enabled
            self.bind(self.win,"touchstart",self.ontouchstart);
            self.bind(document,"touchend",self.ontouchend);
            self.bind(document,"touchcancel",self.ontouchend);
            self.bind(document,"touchmove",self.ontouchmove);            
          }
          
          self.bind(self.cursor,"mousedown",self.onmousedown);
          self.bind(self.cursor,"mouseup",self.onmouseup);

          if (self.railh) {
            self.bind(self.cursorh,"mousedown",function(e){self.onmousedown(e,true)});
            self.bind(self.cursorh,"mouseup",function(e){
              if (self.rail.drag&&self.rail.drag.pt==2) return;
              self.rail.drag = false;
              self.hasmoving = false;
              self.hideCursor();
              if (cap.hasmousecapture) document.releaseCapture();
              return self.cancelEvent(e);
            });
          }
		
          if (self.opt.cursordragontouch||!cap.cantouch&&!self.opt.touchbehavior) {

            self.rail.css({"cursor":"default"});
            self.railh&&self.railh.css({"cursor":"default"});          
          
            self.jqbind(self.rail,"mouseenter",function() {
              if (self.canshowonmouseevent) self.showCursor();
              self.rail.active = true;
            });
            self.jqbind(self.rail,"mouseleave",function() { 
              self.rail.active = false;
              if (!self.rail.drag) self.hideCursor();
            });
            
            if (self.opt.sensitiverail) {
              self.bind(self.rail,"click",function(e){self.doRailClick(e,false,false)});
              self.bind(self.rail,"dblclick",function(e){self.doRailClick(e,true,false)});
              self.bind(self.cursor,"click",function(e){self.cancelEvent(e)});
              self.bind(self.cursor,"dblclick",function(e){self.cancelEvent(e)});
            }

            if (self.railh) {
              self.jqbind(self.railh,"mouseenter",function() {
                if (self.canshowonmouseevent) self.showCursor();
                self.rail.active = true;
              });          
              self.jqbind(self.railh,"mouseleave",function() { 
                self.rail.active = false;
                if (!self.rail.drag) self.hideCursor();
              });
              
              if (self.opt.sensitiverail) {
                self.bind(self.railh, "click", function(e){self.doRailClick(e,false,true)});
                self.bind(self.railh, "dblclick", function(e){self.doRailClick(e, true, true) });
                self.bind(self.cursorh, "click", function (e) { self.cancelEvent(e) });
                self.bind(self.cursorh, "dblclick", function (e) { self.cancelEvent(e) });
              }
              
            }
          
          }
    
          if (!cap.cantouch&&!self.opt.touchbehavior) {

            self.bind((cap.hasmousecapture)?self.win:document,"mouseup",self.onmouseup);            
            self.bind(document,"mousemove",self.onmousemove);
            if (self.onclick) self.bind(document,"click",self.onclick);
            
            if (!self.ispage&&self.opt.enablescrollonselection) {
              self.bind(self.win[0],"mousedown",self.onselectionstart);
              self.bind(document,"mouseup",self.onselectionend);
              self.bind(self.cursor,"mouseup",self.onselectionend);
              if (self.cursorh) self.bind(self.cursorh,"mouseup",self.onselectionend);
              self.bind(document,"mousemove",self.onselectiondrag);
            }

						if (self.zoom) {
							self.jqbind(self.zoom,"mouseenter",function() {
								if (self.canshowonmouseevent) self.showCursor();
								self.rail.active = true;
							});          
							self.jqbind(self.zoom,"mouseleave",function() { 
								self.rail.active = false;
								if (!self.rail.drag) self.hideCursor();
							});
						}

          } else {
            
            self.bind((cap.hasmousecapture)?self.win:document,"mouseup",self.ontouchend);
            self.bind(document,"mousemove",self.ontouchmove);
            if (self.onclick) self.bind(document,"click",self.onclick);
            
            if (self.opt.cursordragontouch) {
              self.bind(self.cursor,"mousedown",self.onmousedown);
              self.bind(self.cursor,"mousemove",self.onmousemove);
              self.cursorh&&self.bind(self.cursorh,"mousedown",self.onmousedown);
              self.cursorh&&self.bind(self.cursorh,"mousemove",self.onmousemove);
            }
          
          }
						
					if (self.opt.enablemousewheel) {
						if (!self.isiframe) self.bind((cap.isie&&self.ispage) ? document : self.docscroll,"mousewheel",self.onmousewheel);
						self.bind(self.rail,"mousewheel",self.onmousewheel);
						if (self.railh) self.bind(self.railh,"mousewheel",self.onmousewheelhr);
					}						
						
          if (!self.ispage&&!cap.cantouch&&!(/HTML|BODY/.test(self.win[0].nodeName))) {
            if (!self.win.attr("tabindex")) self.win.attr({"tabindex":tabindexcounter++});
            
            self.jqbind(self.win,"focus",function(e) {
              domfocus = (self.getTarget(e)).id||true;
              self.hasfocus = true;
              if (self.canshowonmouseevent) self.noticeCursor();
            });
            self.jqbind(self.win,"blur",function(e) {
              domfocus = false;
              self.hasfocus = false;
            });
            
            self.jqbind(self.win,"mouseenter",function(e) {
              mousefocus = (self.getTarget(e)).id||true;
              self.hasmousefocus = true;
              if (self.canshowonmouseevent) self.noticeCursor();
            });
            self.jqbind(self.win,"mouseleave",function() {
              mousefocus = false;
              self.hasmousefocus = false;
            });
            
          };
          
        }  // !ie9mobile
        
        //Thanks to http://www.quirksmode.org !!
        self.onkeypress = function(e) {
          if (self.locked&&self.page.maxh==0) return true;
          
          e = (e) ? e : window.e;
          var tg = self.getTarget(e);
          if (tg&&/INPUT|TEXTAREA|SELECT|OPTION/.test(tg.nodeName)) {
            var tp = tg.getAttribute('type')||tg.type||false;            
            if ((!tp)||!(/submit|button|cancel/i.tp)) return true;
          }
          
          if (self.hasfocus||(self.hasmousefocus&&!domfocus)||(self.ispage&&!domfocus&&!mousefocus)) {
            var key = e.keyCode;
            
            if (self.locked&&key!=27) return self.cancelEvent(e);

            var ctrl = e.ctrlKey||false;
            var shift = e.shiftKey || false;
            
            var ret = false;
            switch (key) {
              case 38:
              case 63233: //safari
                self.doScrollBy(24*3);
                ret = true;
                break;
              case 40:
              case 63235: //safari
                self.doScrollBy(-24*3);
                ret = true;
                break;
              case 37:
              case 63232: //safari
                if (self.railh) {
                  (ctrl) ? self.doScrollLeft(0) : self.doScrollLeftBy(24*3);
                  ret = true;
                }
                break;
              case 39:
              case 63234: //safari
                if (self.railh) {
                  (ctrl) ? self.doScrollLeft(self.page.maxw) : self.doScrollLeftBy(-24*3);
                  ret = true;
                }
                break;
              case 33:
              case 63276: // safari
                self.doScrollBy(self.view.h);
                ret = true;
                break;
              case 34:
              case 63277: // safari
                self.doScrollBy(-self.view.h);
                ret = true;
                break;
              case 36:
              case 63273: // safari                
                (self.railh&&ctrl) ? self.doScrollPos(0,0) : self.doScrollTo(0);
                ret = true;
                break;
              case 35:
              case 63275: // safari
                (self.railh&&ctrl) ? self.doScrollPos(self.page.maxw,self.page.maxh) : self.doScrollTo(self.page.maxh);
                ret = true;
                break;
              case 32:
                if (self.opt.spacebarenabled) {
                  (shift) ? self.doScrollBy(self.view.h) : self.doScrollBy(-self.view.h);
                  ret = true;
                }
                break;
              case 27: // ESC
                if (self.zoomactive) {
                  self.doZoom();
                  ret = true;
                }
                break;
            }
            if (ret) return self.cancelEvent(e);
          }
        };
        
        if (self.opt.enablekeyboard) self.bind(document,(cap.isopera&&!cap.isopera12)?"keypress":"keydown",self.onkeypress);
        
        self.bind(window,'resize',self.lazyResize);
        self.bind(window,'orientationchange',self.lazyResize);
        
        self.bind(window,"load",self.lazyResize);
		
        if (cap.ischrome&&!self.ispage&&!self.haswrapper) { //chrome void scrollbar bug - it persists in version 26
          var tmp=self.win.attr("style");
					var ww = parseFloat(self.win.css("width"))+1;
          self.win.css('width',ww);
          self.synched("chromefix",function(){self.win.attr("style",tmp)});
        }
        
        
// Trying a cross-browser implementation - good luck!

        self.onAttributeChange = function(e) {
          self.lazyResize(250);
        }
        
        if (!self.ispage&&!self.haswrapper) {
          // redesigned MutationObserver for Chrome18+/Firefox14+/iOS6+ with support for: remove div, add/remove content
          if (clsMutationObserver !== false) {
            self.observer = new clsMutationObserver(function(mutations) {            
              mutations.forEach(self.onAttributeChange);
            });
            self.observer.observe(self.win[0],{childList: true, characterData: false, attributes: true, subtree: false});
            
            self.observerremover = new clsMutationObserver(function(mutations) {
               mutations.forEach(function(mo){
                 if (mo.removedNodes.length>0) {
                   for (var dd in mo.removedNodes) {
                     if (mo.removedNodes[dd]==self.win[0]) return self.remove();
                   }
                 }
               });
            });
            self.observerremover.observe(self.win[0].parentNode,{childList: true, characterData: false, attributes: false, subtree: false});
            
          } else {        
            self.bind(self.win,(cap.isie&&!cap.isie9)?"propertychange":"DOMAttrModified",self.onAttributeChange);            
            if (cap.isie9) self.win[0].attachEvent("onpropertychange",self.onAttributeChange); //IE9 DOMAttrModified bug
            self.bind(self.win,"DOMNodeRemoved",function(e){
              if (e.target==self.win[0]) self.remove();
            });
          }
        }
        
//

        if (!self.ispage&&self.opt.boxzoom) self.bind(window,"resize",self.resizeZoom);
        if (self.istextarea) self.bind(self.win,"mouseup",self.lazyResize);
        
        self.checkrtlmode = true;
        self.lazyResize(30);
        
      }
      
      if (this.doc[0].nodeName == 'IFRAME') {
        function oniframeload(e) {
          self.iframexd = false;
          try {
            var doc = 'contentDocument' in this ? this.contentDocument : this.contentWindow.document;
            var a = doc.domain;            
          } catch(e){self.iframexd = true;doc=false};
          
          if (self.iframexd) {
            if ("console" in window) console.log('NiceScroll error: policy restriced iframe');
            return true;  //cross-domain - I can't manage this        
          }
          
          self.forcescreen = true;
          
          if (self.isiframe) {            
            self.iframe = {
              "doc":$(doc),
              "html":self.doc.contents().find('html')[0],
              "body":self.doc.contents().find('body')[0]
            };
            self.getContentSize = function(){
              return {
                w:Math.max(self.iframe.html.scrollWidth,self.iframe.body.scrollWidth),
                h:Math.max(self.iframe.html.scrollHeight,self.iframe.body.scrollHeight)
              }
            }            
            self.docscroll = $(self.iframe.body);//$(this.contentWindow);
          }
          
          if (!cap.isios&&self.opt.iframeautoresize&&!self.isiframe) {
            self.win.scrollTop(0); // reset position
            self.doc.height("");  //reset height to fix browser bug
            var hh=Math.max(doc.getElementsByTagName('html')[0].scrollHeight,doc.body.scrollHeight);
            self.doc.height(hh);          
          }
          self.lazyResize(30);
          
          if (cap.isie7) self.css($(self.iframe.html),{'overflow-y':'hidden'});
          //self.css($(doc.body),{'overflow-y':'hidden'});
          self.css($(self.iframe.body),{'overflow-y':'hidden'});
          
          if ('contentWindow' in this) {
            self.bind(this.contentWindow,"scroll",self.onscroll);  //IE8 & minor
          } else {          
            self.bind(doc,"scroll",self.onscroll);
          }                    
          
          if (self.opt.enablemousewheel) {
            self.bind(doc,"mousewheel",self.onmousewheel);
          }
          
          if (self.opt.enablekeyboard) self.bind(doc,(cap.isopera)?"keypress":"keydown",self.onkeypress);
          
          if (cap.cantouch||self.opt.touchbehavior) {
            self.bind(doc,"mousedown",self.onmousedown);
            self.bind(doc,"mousemove",function(e){self.onmousemove(e,true)});
            if (self.opt.grabcursorenabled&&cap.cursorgrabvalue) self.css($(doc.body),{'cursor':cap.cursorgrabvalue});
          }
          
          self.bind(doc,"mouseup",self.onmouseup);
          
          if (self.zoom) {
            if (self.opt.dblclickzoom) self.bind(doc,'dblclick',self.doZoom);
            if (self.ongesturezoom) self.bind(doc,"gestureend",self.ongesturezoom);             
          }
        };
        
        if (this.doc[0].readyState&&this.doc[0].readyState=="complete"){
          setTimeout(function(){oniframeload.call(self.doc[0],false)},500);
        }
        self.bind(this.doc,"load",oniframeload);
        
      }
      
    };
    
    this.showCursor = function(py,px) {
      if (self.cursortimeout) {
        clearTimeout(self.cursortimeout);
        self.cursortimeout = 0;
      }
      if (!self.rail) return;
      if (self.autohidedom) {
        self.autohidedom.stop().css({opacity:self.opt.cursoropacitymax});
        self.cursoractive = true;
      }
      
      if (!self.rail.drag||self.rail.drag.pt!=1) {      
        if ((typeof py != "undefined")&&(py!==false)) {
          self.scroll.y = Math.round(py * 1/self.scrollratio.y);
        }
        if (typeof px != "undefined") {
          self.scroll.x = Math.round(px * 1/self.scrollratio.x);
        }
      }
      
      self.cursor.css({height:self.cursorheight,top:self.scroll.y}); 
      if (self.cursorh) {
        (!self.rail.align&&self.rail.visibility) ? self.cursorh.css({width:self.cursorwidth,left:self.scroll.x+self.rail.width}) : self.cursorh.css({width:self.cursorwidth,left:self.scroll.x});
        self.cursoractive = true;
      }
      
      if (self.zoom) self.zoom.stop().css({opacity:self.opt.cursoropacitymax});      
    };
    
    this.hideCursor = function(tm) {
      if (self.cursortimeout) return;
      if (!self.rail) return;
      if (!self.autohidedom) return;
      self.cursortimeout = setTimeout(function() {
         if (!self.rail.active||!self.showonmouseevent) {
           self.autohidedom.stop().animate({opacity:self.opt.cursoropacitymin});
           if (self.zoom) self.zoom.stop().animate({opacity:self.opt.cursoropacitymin});
           self.cursoractive = false;
         }
         self.cursortimeout = 0;
      },tm||self.opt.hidecursordelay);
    };
    
    this.noticeCursor = function(tm,py,px) {
      self.showCursor(py,px);
      if (!self.rail.active) self.hideCursor(tm);
    };
        
    this.getContentSize = 
      (self.ispage) ?
        function(){
          return {
            w:Math.max(document.body.scrollWidth,document.documentElement.scrollWidth),
            h:Math.max(document.body.scrollHeight,document.documentElement.scrollHeight)
          }
        }
      : (self.haswrapper) ?
        function(){
          return {
            w:self.doc.outerWidth()+parseInt(self.win.css('paddingLeft'))+parseInt(self.win.css('paddingRight')),
            h:self.doc.outerHeight()+parseInt(self.win.css('paddingTop'))+parseInt(self.win.css('paddingBottom'))
          }
        }
      : function() {        
        return {
          w:self.docscroll[0].scrollWidth,
          h:self.docscroll[0].scrollHeight
        }
      };
  
    this.onResize = function(e,page) {
    
	  if (!self.win) return false;
	
      if (!self.haswrapper&&!self.ispage) {
        if (self.win.css('display')=='none') {
          if (self.visibility) self.hideRail().hideRailHr();
          return false;
        } else {          
          if (!self.hidden&&!self.visibility) self.showRail().showRailHr();
        }        
      }
    
      var premaxh = self.page.maxh;
      var premaxw = self.page.maxw;

      var preview = {h:self.view.h,w:self.view.w};   
      
      self.view = {
        w:(self.ispage) ? self.win.width() : parseInt(self.win[0].clientWidth),
        h:(self.ispage) ? self.win.height() : parseInt(self.win[0].clientHeight)
      };
      
      self.page = (page) ? page : self.getContentSize();
      
      self.page.maxh = Math.max(0,self.page.h - self.view.h);
      self.page.maxw = Math.max(0,self.page.w - self.view.w);
      
      if ((self.page.maxh==premaxh)&&(self.page.maxw==premaxw)&&(self.view.w==preview.w)) {
        // test position        
        if (!self.ispage) {
          var pos = self.win.offset();
          if (self.lastposition) {
            var lst = self.lastposition;
            if ((lst.top==pos.top)&&(lst.left==pos.left)) return self; //nothing to do            
          }
          self.lastposition = pos;
        } else {
          return self; //nothing to do
        }
      }
      
      if (self.page.maxh==0) {
        self.hideRail();        
        self.scrollvaluemax = 0;
        self.scroll.y = 0;
        self.scrollratio.y = 0;
        self.cursorheight = 0;
        self.setScrollTop(0);
        self.rail.scrollable = false;
      } else {       
        self.rail.scrollable = true;
      }
      
      if (self.page.maxw==0) {
        self.hideRailHr();
        self.scrollvaluemaxw = 0;
        self.scroll.x = 0;
        self.scrollratio.x = 0;
        self.cursorwidth = 0;
        self.setScrollLeft(0);
        self.railh.scrollable = false;
      } else {        
        self.railh.scrollable = true;
      }
  
      self.locked = (self.page.maxh==0)&&(self.page.maxw==0);
      if (self.locked) {
				if (!self.ispage) self.updateScrollBar(self.view);
			  return false;
		  }

      if (!self.hidden&&!self.visibility) {
        self.showRail().showRailHr();
      }      
      else if (!self.hidden&&!self.railh.visibility) self.showRailHr();
      
      if (self.istextarea&&self.win.css('resize')&&self.win.css('resize')!='none') self.view.h-=20;      

      self.cursorheight = Math.min(self.view.h,Math.round(self.view.h * (self.view.h / self.page.h)));
      self.cursorheight = (self.opt.cursorfixedheight) ? self.opt.cursorfixedheight : Math.max(self.opt.cursorminheight,self.cursorheight);

      self.cursorwidth = Math.min(self.view.w,Math.round(self.view.w * (self.view.w / self.page.w)));
      self.cursorwidth = (self.opt.cursorfixedheight) ? self.opt.cursorfixedheight : Math.max(self.opt.cursorminheight,self.cursorwidth);
      
      self.scrollvaluemax = self.view.h-self.cursorheight-self.cursor.hborder;
      
      if (self.railh) {
        self.railh.width = (self.page.maxh>0) ? (self.view.w-self.rail.width) : self.view.w;
        self.scrollvaluemaxw = self.railh.width-self.cursorwidth-self.cursorh.wborder;
      }
      
      if (self.checkrtlmode&&self.railh) {
        self.checkrtlmode = false;
        if (self.opt.rtlmode&&self.scroll.x==0) self.setScrollLeft(self.page.maxw);
      }
      
      if (!self.ispage) self.updateScrollBar(self.view);
      
      self.scrollratio = {
        x:(self.page.maxw/self.scrollvaluemaxw),
        y:(self.page.maxh/self.scrollvaluemax)
      };
     
      var sy = self.getScrollTop();
      if (sy>self.page.maxh) {
        self.doScrollTop(self.page.maxh);
      } else {     
        self.scroll.y = Math.round(self.getScrollTop() * (1/self.scrollratio.y));
        self.scroll.x = Math.round(self.getScrollLeft() * (1/self.scrollratio.x));
        if (self.cursoractive) self.noticeCursor();     
      }      
      
      if (self.scroll.y&&(self.getScrollTop()==0)) self.doScrollTo(Math.floor(self.scroll.y*self.scrollratio.y));
      
      return self;
    };
    
    this.resize = self.onResize;
    
    this.lazyResize = function(tm) {   // event debounce
      tm = (isNaN(tm)) ? 30 : tm;
      self.delayed('resize',self.resize,tm);
      return self;
    }
   
// modified by MDN https://developer.mozilla.org/en-US/docs/DOM/Mozilla_event_reference/wheel
    function _modernWheelEvent(dom,name,fn,bubble) {      
      self._bind(dom,name,function(e){
        var  e = (e) ? e : window.event;
        var event = {
          original: e,
          target: e.target || e.srcElement,
          type: "wheel",
          deltaMode: e.type == "MozMousePixelScroll" ? 0 : 1,
          deltaX: 0,
          deltaZ: 0,
          preventDefault: function() {
            e.preventDefault ? e.preventDefault() : e.returnValue = false;
            return false;
          },
          stopImmediatePropagation: function() {
            (e.stopImmediatePropagation) ? e.stopImmediatePropagation() : e.cancelBubble = true;
          }
        };
            
        if (name=="mousewheel") {
          event.deltaY = - 1/40 * e.wheelDelta;
          e.wheelDeltaX && (event.deltaX = - 1/40 * e.wheelDeltaX);
        } else {
          event.deltaY = e.detail;
        }

        return fn.call(dom,event);      
      },bubble);
    };     
   
    this._bind = function(el,name,fn,bubble) {  // primitive bind
      self.events.push({e:el,n:name,f:fn,b:bubble,q:false});
      if (el.addEventListener) {
        el.addEventListener(name,fn,bubble||false);
      }
      else if (el.attachEvent) {
        el.attachEvent("on"+name,fn);
      }
      else {
        el["on"+name] = fn;        
      }        
    };
   
    this.jqbind = function(dom,name,fn) {  // use jquery bind for non-native events (mouseenter/mouseleave)
      self.events.push({e:dom,n:name,f:fn,q:true});
      $(dom).bind(name,fn);
    }
   
    this.bind = function(dom,name,fn,bubble) {  // touch-oriented & fixing jquery bind
      var el = ("jquery" in dom) ? dom[0] : dom;
      
      if (name=='mousewheel') {
        if ("onwheel" in self.win) {            
          self._bind(el,"wheel",fn,bubble||false);
        } else {            
          var wname = (typeof document.onmousewheel != "undefined") ? "mousewheel" : "DOMMouseScroll";  // older IE/Firefox
          _modernWheelEvent(el,wname,fn,bubble||false);
          if (wname=="DOMMouseScroll") _modernWheelEvent(el,"MozMousePixelScroll",fn,bubble||false);  // Firefox legacy
        }
      } 
      else if (el.addEventListener) {
        if (cap.cantouch && /mouseup|mousedown|mousemove/.test(name)) {  // touch device support
          var tt=(name=='mousedown')?'touchstart':(name=='mouseup')?'touchend':'touchmove';
          self._bind(el,tt,function(e){
            if (e.touches) {
              if (e.touches.length<2) {var ev=(e.touches.length)?e.touches[0]:e;ev.original=e;fn.call(this,ev);}
            } 
            else if (e.changedTouches) {var ev=e.changedTouches[0];ev.original=e;fn.call(this,ev);}  //blackberry
          },bubble||false);
        }
        self._bind(el,name,fn,bubble||false);
        if (cap.cantouch && name=="mouseup") self._bind(el,"touchcancel",fn,bubble||false);
      }
      else {
        self._bind(el,name,function(e) {
          e = e||window.event||false;
          if (e) {
            if (e.srcElement) e.target=e.srcElement;
          }
          if (!("pageY" in e)) {
            e.pageX = e.clientX + document.documentElement.scrollLeft;
            e.pageY = e.clientY + document.documentElement.scrollTop; 
          }
          return ((fn.call(el,e)===false)||bubble===false) ? self.cancelEvent(e) : true;
        });
      } 
    };
    
    this._unbind = function(el,name,fn,bub) {  // primitive unbind
      if (el.removeEventListener) {
        el.removeEventListener(name,fn,bub);
      }
      else if (el.detachEvent) {
        el.detachEvent('on'+name,fn);
      } else {
        el['on'+name] = false;
      }
    };
    
    this.unbindAll = function() {
      for(var a=0;a<self.events.length;a++) {
        var r = self.events[a];        
        (r.q) ? r.e.unbind(r.n,r.f) : self._unbind(r.e,r.n,r.f,r.b);
      }
    };
    
    // Thanks to http://www.switchonthecode.com !!
    this.cancelEvent = function(e) {
      var e = (e.original) ? e.original : (e) ? e : window.event||false;
      if (!e) return false;      
      if(e.preventDefault) e.preventDefault();
      if(e.stopPropagation) e.stopPropagation();
      if(e.preventManipulation) e.preventManipulation();  //IE10
      e.cancelBubble = true;
      e.cancel = true;
      e.returnValue = false;
      return false;
    };

    this.stopPropagation = function(e) {
      var e = (e.original) ? e.original : (e) ? e : window.event||false;
      if (!e) return false;
      if (e.stopPropagation) return e.stopPropagation();
      if (e.cancelBubble) e.cancelBubble=true;
      return false;
    }
    
    this.showRail = function() {
      if ((self.page.maxh!=0)&&(self.ispage||self.win.css('display')!='none')) {
        self.visibility = true;
        self.rail.visibility = true;
        self.rail.css('display','block');
      }
      return self;
    };

    this.showRailHr = function() {
      if (!self.railh) return self;
      if ((self.page.maxw!=0)&&(self.ispage||self.win.css('display')!='none')) {
        self.railh.visibility = true;
        self.railh.css('display','block');
      }
      return self;
    };
    
    this.hideRail = function() {
      self.visibility = false;
      self.rail.visibility = false;
      self.rail.css('display','none');
      return self;
    };

    this.hideRailHr = function() {
      if (!self.railh) return self;
      self.railh.visibility = false;
      self.railh.css('display','none');
      return self;
    };
    
    this.show = function() {
      self.hidden = false;
      self.locked = false;
      return self.showRail().showRailHr();
    };

    this.hide = function() {
      self.hidden = true;
      self.locked = true;
      return self.hideRail().hideRailHr();
    };
    
    this.toggle = function() {
      return (self.hidden) ? self.show() : self.hide();
    };
    
    this.remove = function() {
      self.stop();
      if (self.cursortimeout) clearTimeout(self.cursortimeout);
      self.doZoomOut();
      self.unbindAll();      
      if (self.observer !== false) self.observer.disconnect();
      if (self.observerremover !== false) self.observerremover.disconnect();      
      self.events = [];
      if (self.cursor) {
        self.cursor.remove();
        self.cursor = null;
      }
      if (self.cursorh) {
        self.cursorh.remove();
        self.cursorh = null;
      }
      if (self.rail) {
        self.rail.remove();
        self.rail = null;
      }
      if (self.railh) {
        self.railh.remove();
        self.railh = null;
      }
      if (self.zoom) {
        self.zoom.remove();
        self.zoom = null;
      }
      for(var a=0;a<self.saved.css.length;a++) {
        var d=self.saved.css[a];
        d[0].css(d[1],(typeof d[2]=="undefined") ? '' : d[2]);
      }
      self.saved = false;      
      self.me.data('__nicescroll',''); //erase all traces
	  self.me = null;
	  self.doc = null;
	  self.docscroll = null;
	  self.win = null;
      return self;
    };
    
    this.scrollstart = function(fn) {
      this.onscrollstart = fn;
      return self;
    }
    this.scrollend = function(fn) {
      this.onscrollend = fn;
      return self;
    }
    this.scrollcancel = function(fn) {
      this.onscrollcancel = fn;
      return self;
    }
    
    this.zoomin = function(fn) {
      this.onzoomin = fn;
      return self;
    }
    this.zoomout = function(fn) {
      this.onzoomout = fn;
      return self;
    }
    
    this.isScrollable = function(e) {      
      var dom = (e.target) ? e.target : e;
      if (dom.nodeName == 'OPTION') return true;
      while (dom&&(dom.nodeType==1)&&!(/BODY|HTML/.test(dom.nodeName))) {
        var dd = $(dom);
        var ov = dd.css('overflowY')||dd.css('overflowX')||dd.css('overflow')||'';
        if (/scroll|auto/.test(ov)) return (dom.clientHeight!=dom.scrollHeight);
        dom = (dom.parentNode) ? dom.parentNode : false;        
      }
      return false;
    };

    this.getViewport = function(me) {      
      var dom = (me&&me.parentNode) ? me.parentNode : false;
      while (dom&&(dom.nodeType==1)&&!(/BODY|HTML/.test(dom.nodeName))) {
        var dd = $(dom);
        var ov = dd.css('overflowY')||dd.css('overflowX')||dd.css('overflow')||'';
        if ((/scroll|auto/.test(ov))&&(dom.clientHeight!=dom.scrollHeight)) return dd;
        if (dd.getNiceScroll().length>0) return dd;
        dom = (dom.parentNode) ? dom.parentNode : false;
      }
      return false;
    };
    
    function execScrollWheel(e,hr,chkscroll) {
      var px,py;
      var rt = 1;

      if (e.deltaMode==0) {  // PIXEL
        px = -Math.floor(e.deltaX*(self.opt.mousescrollstep/(18*3)));
        py = -Math.floor(e.deltaY*(self.opt.mousescrollstep/(18*3)));
      }
      else if (e.deltaMode==1) {  // LINE
        px = -Math.floor(e.deltaX*self.opt.mousescrollstep);
        py = -Math.floor(e.deltaY*self.opt.mousescrollstep);
      }
      
      if (hr&&(px==0)&&py) {  // classic vertical-only mousewheel + browser with x/y support 
        px = py;
        py = 0;
      }

      if (px) {
        if (self.scrollmom) {self.scrollmom.stop()}
        self.lastdeltax+=px;
        self.debounced("mousewheelx",function(){var dt=self.lastdeltax;self.lastdeltax=0;if(!self.rail.drag){self.doScrollLeftBy(dt)}},120);
      }
      if (py) {
        if (self.opt.nativeparentscrolling&&chkscroll&&!self.ispage&&!self.zoomactive) {
          if (py<0) {
            if (self.getScrollTop()>=self.page.maxh) return true;
          } else {
            if (self.getScrollTop()<=0) return true;
          }
        }
        if (self.scrollmom) {self.scrollmom.stop()}
        self.lastdeltay+=py;
        self.debounced("mousewheely",function(){var dt=self.lastdeltay;self.lastdeltay=0;if(!self.rail.drag){self.doScrollBy(dt)}},120);
      }
      
      e.stopImmediatePropagation();
      return e.preventDefault();
//      return self.cancelEvent(e);
    };
    
    this.onmousewheel = function(e) {
      if (self.locked) return true;
      if (self.rail.drag) return self.cancelEvent(e);
      
      if (!self.rail.scrollable) {
        if (self.railh&&self.railh.scrollable) {
          return self.onmousewheelhr(e);
        } else {
          return true;
        }
      }
      
      var nw = +(new Date());
      var chk = false;
      if (self.opt.preservenativescrolling&&((self.checkarea+600)<nw)) {
//        self.checkarea = false;
        self.nativescrollingarea = self.isScrollable(e);
        chk = true;
      }
      self.checkarea = nw;
      if (self.nativescrollingarea) return true; // this isn't my business
//      if (self.locked) return self.cancelEvent(e);
      var ret = execScrollWheel(e,false,chk);
      if (ret) self.checkarea = 0;
      return ret;
    };

    this.onmousewheelhr = function(e) {
      if (self.locked||!self.railh.scrollable) return true;
      if (self.rail.drag) return self.cancelEvent(e);
      
      var nw = +(new Date());
      var chk = false;
      if (self.opt.preservenativescrolling&&((self.checkarea+600)<nw)) {
//        self.checkarea = false;
        self.nativescrollingarea = self.isScrollable(e); 
        chk = true;
      }
      self.checkarea = nw;
      if (self.nativescrollingarea) return true; // this isn't my business
      if (self.locked) return self.cancelEvent(e);

      return execScrollWheel(e,true,chk);
    };
    
    this.stop = function() {
      self.cancelScroll();
      if (self.scrollmon) self.scrollmon.stop();
      self.cursorfreezed = false;
      self.scroll.y = Math.round(self.getScrollTop() * (1/self.scrollratio.y));      
      self.noticeCursor();
      return self;
    };
    
    this.getTransitionSpeed = function(dif) {
      var sp = Math.round(self.opt.scrollspeed*10);
      var ex = Math.min(sp,Math.round((dif / 20) * self.opt.scrollspeed));
      return (ex>20) ? ex : 0;
    }
    
    if (!self.opt.smoothscroll) {
      this.doScrollLeft = function(x,spd) {  //direct
        var y = self.getScrollTop();
        self.doScrollPos(x,y,spd);
      }      
      this.doScrollTop = function(y,spd) {   //direct
        var x = self.getScrollLeft();
        self.doScrollPos(x,y,spd);
      }
      this.doScrollPos = function(x,y,spd) {  //direct
        var nx = (x>self.page.maxw) ? self.page.maxw : x;
        if (nx<0) nx=0;
        var ny = (y>self.page.maxh) ? self.page.maxh : y;
        if (ny<0) ny=0;
        self.synched('scroll',function(){
          self.setScrollTop(ny);
          self.setScrollLeft(nx);
        });
      }
      this.cancelScroll = function() {}; // direct
    } 
    else if (self.ishwscroll&&cap.hastransition&&self.opt.usetransition) {
      this.prepareTransition = function(dif,istime) {
        var ex = (istime) ? ((dif>20)?dif:0) : self.getTransitionSpeed(dif);        
        var trans = (ex) ? cap.prefixstyle+'transform '+ex+'ms ease-out' : '';
        if (!self.lasttransitionstyle||self.lasttransitionstyle!=trans) {
          self.lasttransitionstyle = trans;
          self.doc.css(cap.transitionstyle,trans);
        }
        return ex;
      };
      
      this.doScrollLeft = function(x,spd) {  //trans
        var y = (self.scrollrunning) ? self.newscrolly : self.getScrollTop();
        self.doScrollPos(x,y,spd);
      }      
      
      this.doScrollTop = function(y,spd) {   //trans
        var x = (self.scrollrunning) ? self.newscrollx : self.getScrollLeft();
        self.doScrollPos(x,y,spd);
      }
      
      this.doScrollPos = function(x,y,spd) {  //trans
   
        var py = self.getScrollTop();
        var px = self.getScrollLeft();        
      
        if (((self.newscrolly-py)*(y-py)<0)||((self.newscrollx-px)*(x-px)<0)) self.cancelScroll();  //inverted movement detection      
        
        if (self.opt.bouncescroll==false) {
          if (y<0) y=0;
          else if (y>self.page.maxh) y=self.page.maxh;
          if (x<0) x=0;
          else if (x>self.page.maxw) x=self.page.maxw;
        }
        
        if (self.scrollrunning&&x==self.newscrollx&&y==self.newscrolly) return false;
        
        self.newscrolly = y;
        self.newscrollx = x;
        
        self.newscrollspeed = spd||false;
        
        if (self.timer) return false;
        
        self.timer = setTimeout(function(){
        
          var top = self.getScrollTop();
          var lft = self.getScrollLeft();
          
          var dst = {};
          dst.x = x-lft;
          dst.y = y-top;
          dst.px = lft;
          dst.py = top;
          
          var dd = Math.round(Math.sqrt(Math.pow(dst.x,2)+Math.pow(dst.y,2)));          
          
//          var df = (self.newscrollspeed) ? self.newscrollspeed : dd;
          
          var ms = (self.newscrollspeed && self.newscrollspeed>1) ? self.newscrollspeed : self.getTransitionSpeed(dd);
          if (self.newscrollspeed&&self.newscrollspeed<=1) ms*=self.newscrollspeed;
          
          self.prepareTransition(ms,true);
          
          if (self.timerscroll&&self.timerscroll.tm) clearInterval(self.timerscroll.tm);    
          
          if (ms>0) {
          
            if (!self.scrollrunning&&self.onscrollstart) {
              var info = {"type":"scrollstart","current":{"x":lft,"y":top},"request":{"x":x,"y":y},"end":{"x":self.newscrollx,"y":self.newscrolly},"speed":ms};
              self.onscrollstart.call(self,info);
            }
            
            if (cap.transitionend) {
              if (!self.scrollendtrapped) {
                self.scrollendtrapped = true;
                self.bind(self.doc,cap.transitionend,self.onScrollEnd,false); //I have got to do something usefull!!
              }
            } else {              
              if (self.scrollendtrapped) clearTimeout(self.scrollendtrapped);
              self.scrollendtrapped = setTimeout(self.onScrollEnd,ms);  // simulate transitionend event
            }
            
            var py = top;
            var px = lft;
            self.timerscroll = {
              bz: new BezierClass(py,self.newscrolly,ms,0,0,0.58,1),
              bh: new BezierClass(px,self.newscrollx,ms,0,0,0.58,1)
            };            
            if (!self.cursorfreezed) self.timerscroll.tm=setInterval(function(){self.showCursor(self.getScrollTop(),self.getScrollLeft())},60);
            
          }
          
          self.synched("doScroll-set",function(){
            self.timer = 0;
            if (self.scrollendtrapped) self.scrollrunning = true;
            self.setScrollTop(self.newscrolly);
            self.setScrollLeft(self.newscrollx);
            if (!self.scrollendtrapped) self.onScrollEnd();
          });
          
          
        },50);
        
      };
      
      this.cancelScroll = function() {
        if (!self.scrollendtrapped) return true;        
        var py = self.getScrollTop();
        var px = self.getScrollLeft();
        self.scrollrunning = false;
        if (!cap.transitionend) clearTimeout(cap.transitionend);
        self.scrollendtrapped = false;
        self._unbind(self.doc,cap.transitionend,self.onScrollEnd);        
        self.prepareTransition(0);
        self.setScrollTop(py); // fire event onscroll
        if (self.railh) self.setScrollLeft(px);
        if (self.timerscroll&&self.timerscroll.tm) clearInterval(self.timerscroll.tm);
        self.timerscroll = false;
        
        self.cursorfreezed = false;

        //self.noticeCursor(false,py,px);
        self.showCursor(py,px);
        return self;
      };
      this.onScrollEnd = function() {                
        if (self.scrollendtrapped) self._unbind(self.doc,cap.transitionend,self.onScrollEnd);
        self.scrollendtrapped = false;        
        self.prepareTransition(0);
        if (self.timerscroll&&self.timerscroll.tm) clearInterval(self.timerscroll.tm);
        self.timerscroll = false;        
        var py = self.getScrollTop();
        var px = self.getScrollLeft();
        self.setScrollTop(py);  // fire event onscroll        
        if (self.railh) self.setScrollLeft(px);  // fire event onscroll left
        
        self.noticeCursor(false,py,px);     
        
        self.cursorfreezed = false;
        
        if (py<0) py=0
        else if (py>self.page.maxh) py=self.page.maxh;
        if (px<0) px=0
        else if (px>self.page.maxw) px=self.page.maxw;
        if((py!=self.newscrolly)||(px!=self.newscrollx)) return self.doScrollPos(px,py,self.opt.snapbackspeed);
        
        if (self.onscrollend&&self.scrollrunning) {
          var info = {"type":"scrollend","current":{"x":px,"y":py},"end":{"x":self.newscrollx,"y":self.newscrolly}};
          self.onscrollend.call(self,info);
        } 
        self.scrollrunning = false;
        
      };

    } else {

      this.doScrollLeft = function(x,spd) {  //no-trans
        var y = (self.scrollrunning) ? self.newscrolly : self.getScrollTop();
        self.doScrollPos(x,y,spd);
      }

      this.doScrollTop = function(y,spd) {  //no-trans
        var x = (self.scrollrunning) ? self.newscrollx : self.getScrollLeft();
        self.doScrollPos(x,y,spd);
      }

      this.doScrollPos = function(x,y,spd) {  //no-trans
        var y = ((typeof y == "undefined")||(y===false)) ? self.getScrollTop(true) : y;
      
        if  ((self.timer)&&(self.newscrolly==y)&&(self.newscrollx==x)) return true;
      
        if (self.timer) clearAnimationFrame(self.timer);
        self.timer = 0;      

        var py = self.getScrollTop();
        var px = self.getScrollLeft();
        
        if (((self.newscrolly-py)*(y-py)<0)||((self.newscrollx-px)*(x-px)<0)) self.cancelScroll();  //inverted movement detection
        
        self.newscrolly = y;
        self.newscrollx = x;
        
        if (!self.bouncescroll||!self.rail.visibility) {
          if (self.newscrolly<0) {
            self.newscrolly = 0;
          }
          else if (self.newscrolly>self.page.maxh) {
            self.newscrolly = self.page.maxh;
          }
        }
        if (!self.bouncescroll||!self.railh.visibility) {
          if (self.newscrollx<0) {
            self.newscrollx = 0;
          }
          else if (self.newscrollx>self.page.maxw) {
            self.newscrollx = self.page.maxw;
          }
        }

        self.dst = {};
        self.dst.x = x-px;
        self.dst.y = y-py;
        self.dst.px = px;
        self.dst.py = py;
        
        var dst = Math.round(Math.sqrt(Math.pow(self.dst.x,2)+Math.pow(self.dst.y,2)));
        
        self.dst.ax = self.dst.x / dst;
        self.dst.ay = self.dst.y / dst;
        
        var pa = 0;
        var pe = dst;
        
        if (self.dst.x==0) {
          pa = py;
          pe = y;
          self.dst.ay = 1;
          self.dst.py = 0;
        } else if (self.dst.y==0) {
          pa = px;
          pe = x;
          self.dst.ax = 1;
          self.dst.px = 0;
        }

        var ms = self.getTransitionSpeed(dst);
        if (spd&&spd<=1) ms*=spd;
        if (ms>0) {
          self.bzscroll = (self.bzscroll) ? self.bzscroll.update(pe,ms) : new BezierClass(pa,pe,ms,0,1,0,1);
        } else {
          self.bzscroll = false;
        }
        
        if (self.timer) return;
        
        if ((py==self.page.maxh&&y>=self.page.maxh)||(px==self.page.maxw&&x>=self.page.maxw)) self.checkContentSize();
        
        var sync = 1;
        
        function scrolling() {          
          if (self.cancelAnimationFrame) return true;
          
          self.scrollrunning = true;
          
          sync = 1-sync;
          if (sync) return (self.timer = setAnimationFrame(scrolling)||1);

          var done = 0;
          
          var sc = sy = self.getScrollTop();
          if (self.dst.ay) {            
            sc = (self.bzscroll) ? self.dst.py + (self.bzscroll.getNow()*self.dst.ay) : self.newscrolly;
            var dr=sc-sy;          
            if ((dr<0&&sc<self.newscrolly)||(dr>0&&sc>self.newscrolly)) sc = self.newscrolly;
            self.setScrollTop(sc);
            if (sc == self.newscrolly) done=1;
          } else {
            done=1;
          }
          
          var scx = sx = self.getScrollLeft();
          if (self.dst.ax) {            
            scx = (self.bzscroll) ? self.dst.px + (self.bzscroll.getNow()*self.dst.ax) : self.newscrollx;            
            var dr=scx-sx;
            if ((dr<0&&scx<self.newscrollx)||(dr>0&&scx>self.newscrollx)) scx = self.newscrollx;
            self.setScrollLeft(scx);
            if (scx == self.newscrollx) done+=1;
          } else {
            done+=1;
          }
          
          if (done==2) {
            self.timer = 0;
            self.cursorfreezed = false;
            self.bzscroll = false;
            self.scrollrunning = false;
            if (sc<0) sc=0;
            else if (sc>self.page.maxh) sc=self.page.maxh;
            if (scx<0) scx=0;
            else if (scx>self.page.maxw) scx=self.page.maxw;
            if ((scx!=self.newscrollx)||(sc!=self.newscrolly)) self.doScrollPos(scx,sc);
            else {
              if (self.onscrollend) {
                var info = {"type":"scrollend","current":{"x":sx,"y":sy},"end":{"x":self.newscrollx,"y":self.newscrolly}};
                self.onscrollend.call(self,info);
              }             
            } 
          } else {
            self.timer = setAnimationFrame(scrolling)||1;
          }
        };
        self.cancelAnimationFrame=false;
        self.timer = 1;

        if (self.onscrollstart&&!self.scrollrunning) {
          var info = {"type":"scrollstart","current":{"x":px,"y":py},"request":{"x":x,"y":y},"end":{"x":self.newscrollx,"y":self.newscrolly},"speed":ms};
          self.onscrollstart.call(self,info);
        }        

        scrolling();
        
        if ((py==self.page.maxh&&y>=py)||(px==self.page.maxw&&x>=px)) self.checkContentSize();
        
        self.noticeCursor();
      };
  
      this.cancelScroll = function() {        
        if (self.timer) clearAnimationFrame(self.timer);
        self.timer = 0;
        self.bzscroll = false;
        self.scrollrunning = false;
        return self;
      };
      
    }
    
    this.doScrollBy = function(stp,relative) {
      var ny = 0;
      if (relative) {
        ny = Math.floor((self.scroll.y-stp)*self.scrollratio.y)
      } else {        
        var sy = (self.timer) ? self.newscrolly : self.getScrollTop(true);
        ny = sy-stp;
      }
      if (self.bouncescroll) {
        var haf = Math.round(self.view.h/2);
        if (ny<-haf) ny=-haf
        else if (ny>(self.page.maxh+haf)) ny = (self.page.maxh+haf);
      }
      self.cursorfreezed = false;      

      py = self.getScrollTop(true);
      if (ny<0&&py<=0) return self.noticeCursor();      
      else if (ny>self.page.maxh&&py>=self.page.maxh) {
        self.checkContentSize();
        return self.noticeCursor();
      }
      
      self.doScrollTop(ny);
    };

    this.doScrollLeftBy = function(stp,relative) {
      var nx = 0;
      if (relative) {
        nx = Math.floor((self.scroll.x-stp)*self.scrollratio.x)
      } else {
        var sx = (self.timer) ? self.newscrollx : self.getScrollLeft(true);
        nx = sx-stp;
      }
      if (self.bouncescroll) {
        var haf = Math.round(self.view.w/2);
        if (nx<-haf) nx=-haf
        else if (nx>(self.page.maxw+haf)) nx = (self.page.maxw+haf);
      }
      self.cursorfreezed = false;    

      px = self.getScrollLeft(true);
      if (nx<0&&px<=0) return self.noticeCursor();      
      else if (nx>self.page.maxw&&px>=self.page.maxw) return self.noticeCursor();
      
      self.doScrollLeft(nx);
    };
    
    this.doScrollTo = function(pos,relative) {
      var ny = (relative) ? Math.round(pos*self.scrollratio.y) : pos;
      if (ny<0) ny=0
      else if (ny>self.page.maxh) ny = self.page.maxh;
      self.cursorfreezed = false;
      self.doScrollTop(pos);
    };
    
    this.checkContentSize = function() {      
      var pg = self.getContentSize();
      if ((pg.h!=self.page.h)||(pg.w!=self.page.w)) self.resize(false,pg);
    };
    
    self.onscroll = function(e) {    
      if (self.rail.drag) return;
      if (!self.cursorfreezed) {
        self.synched('scroll',function(){
          self.scroll.y = Math.round(self.getScrollTop() * (1/self.scrollratio.y));
          if (self.railh) self.scroll.x = Math.round(self.getScrollLeft() * (1/self.scrollratio.x));
          self.noticeCursor();
        });
      }
    };
    self.bind(self.docscroll,"scroll",self.onscroll);
    
    this.doZoomIn = function(e) {
      if (self.zoomactive) return;
      self.zoomactive = true;
      
      self.zoomrestore = {
        style:{}
      };
      var lst = ['position','top','left','zIndex','backgroundColor','marginTop','marginBottom','marginLeft','marginRight'];
      var win = self.win[0].style;
      for(var a in lst) {
        var pp = lst[a];
        self.zoomrestore.style[pp] = (typeof win[pp] != "undefined") ? win[pp] : '';        
      }
      
      self.zoomrestore.style.width = self.win.css('width');
      self.zoomrestore.style.height = self.win.css('height');
      
      self.zoomrestore.padding = {
        w:self.win.outerWidth()-self.win.width(),
        h:self.win.outerHeight()-self.win.height()
      };
      
      if (cap.isios4) {
        self.zoomrestore.scrollTop = $(window).scrollTop();
        $(window).scrollTop(0);
      }
      
      self.win.css({
        "position":(cap.isios4)?"absolute":"fixed",
        "top":0,
        "left":0,
        "z-index":globalmaxzindex+100,
        "margin":"0px"
      });
      var bkg = self.win.css("backgroundColor");      
      if (bkg==""||/transparent|rgba\(0, 0, 0, 0\)|rgba\(0,0,0,0\)/.test(bkg)) self.win.css("backgroundColor","#fff");
      self.rail.css({"z-index":globalmaxzindex+101});
      self.zoom.css({"z-index":globalmaxzindex+102});      
      self.zoom.css('backgroundPosition','0px -18px');
      self.resizeZoom();
      
      if (self.onzoomin) self.onzoomin.call(self);
      
      return self.cancelEvent(e);
    };

    this.doZoomOut = function(e) {
      if (!self.zoomactive) return;
      self.zoomactive = false;
      
      self.win.css("margin","");
      self.win.css(self.zoomrestore.style);
      
      if (cap.isios4) {
        $(window).scrollTop(self.zoomrestore.scrollTop);
      }
      
      self.rail.css({"z-index":self.zindex});
      self.zoom.css({"z-index":self.zindex});
      self.zoomrestore = false;
      self.zoom.css('backgroundPosition','0px 0px');
      self.onResize();
      
      if (self.onzoomout) self.onzoomout.call(self);
      
      return self.cancelEvent(e);
    };
    
    this.doZoom = function(e) {
      return (self.zoomactive) ? self.doZoomOut(e) : self.doZoomIn(e);
    };
    
    this.resizeZoom = function() {
      if (!self.zoomactive) return;

      var py = self.getScrollTop(); //preserve scrolling position
      self.win.css({
        width:$(window).width()-self.zoomrestore.padding.w+"px",
        height:$(window).height()-self.zoomrestore.padding.h+"px"
      });
      self.onResize();
      
      self.setScrollTop(Math.min(self.page.maxh,py));
    };
   
    this.init();
    
    $.nicescroll.push(this);

  };
  
// Inspired by the work of Kin Blas
// http://webpro.host.adobe.com/people/jblas/momentum/includes/jquery.momentum.0.7.js  
  
  
  var ScrollMomentumClass2D = function(nc) {
    var self = this;
    this.nc = nc;
    
    this.lastx = 0;
    this.lasty = 0;
    this.speedx = 0;
    this.speedy = 0;
    this.lasttime = 0;
    this.steptime = 0;
    this.snapx = false;
    this.snapy = false;
    this.demulx = 0;
    this.demuly = 0;
    
    this.lastscrollx = -1;
    this.lastscrolly = -1;
    
    this.chkx = 0;
    this.chky = 0;
    
    this.timer = 0;
    
    this.time = function() {
      return +new Date();//beautifull hack
    };
    
    this.reset = function(px,py) {
      self.stop();
      var now = self.time();
      self.steptime = 0;
      self.lasttime = now;
      self.speedx = 0;
      self.speedy = 0;
      self.lastx = px;
      self.lasty = py;
      self.lastscrollx = -1;
      self.lastscrolly = -1;
    };
    
    this.update = function(px,py) {
      var now = self.time();
      self.steptime = now - self.lasttime;
      self.lasttime = now;      
      var dy = py - self.lasty;
      var dx = px - self.lastx;
      var sy = self.nc.getScrollTop();
      var sx = self.nc.getScrollLeft();
      var newy = sy + dy;
      var newx = sx + dx;
      self.snapx = (newx<0)||(newx>self.nc.page.maxw);
      self.snapy = (newy<0)||(newy>self.nc.page.maxh);
      self.speedx = dx;
      self.speedy = dy;
      self.lastx = px;
      self.lasty = py;
    };
    
    this.stop = function() {
      self.nc.unsynched("domomentum2d");
      if (self.timer) clearTimeout(self.timer);
      self.timer = 0;
      self.lastscrollx = -1;
      self.lastscrolly = -1;
    };
    
    this.doSnapy = function(nx,ny) {
      var snap = false;
      
      if (ny<0) {
        ny=0;
        snap=true;        
      } 
      else if (ny>self.nc.page.maxh) {
        ny=self.nc.page.maxh;
        snap=true;
      }

      if (nx<0) {
        nx=0;
        snap=true;        
      } 
      else if (nx>self.nc.page.maxw) {
        nx=self.nc.page.maxw;
        snap=true;
      }
      
      if (snap) self.nc.doScrollPos(nx,ny,self.nc.opt.snapbackspeed);
    };
    
    this.doMomentum = function(gp) {
      var t = self.time();
      var l = (gp) ? t+gp : self.lasttime;

      var sl = self.nc.getScrollLeft();
      var st = self.nc.getScrollTop();
      
      var pageh = self.nc.page.maxh;
      var pagew = self.nc.page.maxw;
      
      self.speedx = (pagew>0) ? Math.min(60,self.speedx) : 0;
      self.speedy = (pageh>0) ? Math.min(60,self.speedy) : 0;
      
      var chk = l && (t - l) <= 50;
      
      if ((st<0)||(st>pageh)||(sl<0)||(sl>pagew)) chk = false;
      
      var sy = (self.speedy && chk) ? self.speedy : false;
      var sx = (self.speedx && chk) ? self.speedx : false;
      
      if (sy||sx) {
        var tm = Math.max(16,self.steptime); //timeout granularity
        
        if (tm>50) {  // do smooth
          var xm = tm/50;
          self.speedx*=xm;
          self.speedy*=xm;
          tm = 50;
        }
        
        self.demulxy = 0;

        self.lastscrollx = self.nc.getScrollLeft();
        self.chkx = self.lastscrollx;
        self.lastscrolly = self.nc.getScrollTop();
        self.chky = self.lastscrolly;
        
        var nx = self.lastscrollx;
        var ny = self.lastscrolly;
        
        var onscroll = function(){
          var df = ((self.time()-t)>600) ? 0.04 : 0.02;
        
          if (self.speedx) {
            nx = Math.floor(self.lastscrollx - (self.speedx*(1-self.demulxy)));
            self.lastscrollx = nx;
            if ((nx<0)||(nx>pagew)) df=0.10;
          }

          if (self.speedy) {
            ny = Math.floor(self.lastscrolly - (self.speedy*(1-self.demulxy)));
            self.lastscrolly = ny;
            if ((ny<0)||(ny>pageh)) df=0.10;
          }
          
          self.demulxy = Math.min(1,self.demulxy+df);
          
          self.nc.synched("domomentum2d",function(){

            if (self.speedx) {
              var scx = self.nc.getScrollLeft();
              if (scx!=self.chkx) self.stop();
              self.chkx=nx;
              self.nc.setScrollLeft(nx);
            }
          
            if (self.speedy) {
              var scy = self.nc.getScrollTop();
              if (scy!=self.chky) self.stop();          
              self.chky=ny;
              self.nc.setScrollTop(ny);
            }
            
            if(!self.timer) {
              self.nc.hideCursor();
              self.doSnapy(nx,ny);
            }
            
          });
          
          if (self.demulxy<1) {            
            self.timer = setTimeout(onscroll,tm);
          } else {
            self.stop();
            self.nc.hideCursor();
            self.doSnapy(nx,ny);
          }
        };
        
        onscroll();
        
      } else {
        self.doSnapy(self.nc.getScrollLeft(),self.nc.getScrollTop());
      }      
      
    }
    
  };

  
// override jQuery scrollTop
 
  var _scrollTop = jQuery.fn.scrollTop; // preserve original function
   
  jQuery.cssHooks["pageYOffset"] = {
    get: function(elem,computed,extra) {      
      var nice = $.data(elem,'__nicescroll')||false;
      return (nice&&nice.ishwscroll) ? nice.getScrollTop() : _scrollTop.call(elem);
    },
    set: function(elem,value) {
      var nice = $.data(elem,'__nicescroll')||false;    
      (nice&&nice.ishwscroll) ? nice.setScrollTop(parseInt(value)) : _scrollTop.call(elem,value);
      return this;
    }
  };
  
/*  
  $.fx.step["scrollTop"] = function(fx){    
    $.cssHooks["scrollTop"].set( fx.elem, fx.now + fx.unit );
  };
*/  
  
  jQuery.fn.scrollTop = function(value) {    
    if (typeof value == "undefined") {
      var nice = (this[0]) ? $.data(this[0],'__nicescroll')||false : false;
      return (nice&&nice.ishwscroll) ? nice.getScrollTop() : _scrollTop.call(this);
    } else {      
      return this.each(function() {
        var nice = $.data(this,'__nicescroll')||false;
        (nice&&nice.ishwscroll) ? nice.setScrollTop(parseInt(value)) : _scrollTop.call($(this),value);
      });
    }
  }

// override jQuery scrollLeft
 
  var _scrollLeft = jQuery.fn.scrollLeft; // preserve original function
   
  $.cssHooks.pageXOffset = {
    get: function(elem,computed,extra) {
      var nice = $.data(elem,'__nicescroll')||false;
      return (nice&&nice.ishwscroll) ? nice.getScrollLeft() : _scrollLeft.call(elem);
    },
    set: function(elem,value) {
      var nice = $.data(elem,'__nicescroll')||false;    
      (nice&&nice.ishwscroll) ? nice.setScrollLeft(parseInt(value)) : _scrollLeft.call(elem,value);
      return this;
    }
  };
  
/*  
  $.fx.step["scrollLeft"] = function(fx){
    $.cssHooks["scrollLeft"].set( fx.elem, fx.now + fx.unit );
  };  
*/  
 
  jQuery.fn.scrollLeft = function(value) {    
    if (typeof value == "undefined") {
      var nice = (this[0]) ? $.data(this[0],'__nicescroll')||false : false;
      return (nice&&nice.ishwscroll) ? nice.getScrollLeft() : _scrollLeft.call(this);
    } else {
      return this.each(function() {     
        var nice = $.data(this,'__nicescroll')||false;
        (nice&&nice.ishwscroll) ? nice.setScrollLeft(parseInt(value)) : _scrollLeft.call($(this),value);
      });
    }
  }
  
  var NiceScrollArray = function(doms) {
    var self = this;
    this.length = 0;
    this.name = "nicescrollarray";
  
    this.each = function(fn) {
      for(var a=0;a<self.length;a++) fn.call(self[a]);
      return self;
    };
    
    this.push = function(nice) {
      self[self.length]=nice;
      self.length++;
    };
    
    this.eq = function(idx) {
      return self[idx];
    };
    
    if (doms) {
      for(a=0;a<doms.length;a++) {
        var nice = $.data(doms[a],'__nicescroll')||false;
        if (nice) {
          this[this.length]=nice;
          this.length++;
        }
      };
    }
    
    return this;
  };
  
  function mplex(el,lst,fn) {
    for(var a=0;a<lst.length;a++) fn(el,lst[a]);
  };  
  mplex(
    NiceScrollArray.prototype,
    ['show','hide','toggle','onResize','resize','remove','stop','doScrollPos'],
    function(e,n) {
      e[n] = function(){
        var args = arguments;
        return this.each(function(){          
          this[n].apply(this,args);
        });
      };
    }
  );  
  
  jQuery.fn.getNiceScroll = function(index) {
    if (typeof index == "undefined") {
      return new NiceScrollArray(this);
    } else {
      var nice = $.data(this[index],'__nicescroll')||false;
      return nice;
    }
  };
  
  jQuery.extend(jQuery.expr[':'], {
    nicescroll: function(a) {
      return ($.data(a,'__nicescroll'))?true:false;
    }
  });  
  
  $.fn.niceScroll = function(wrapper,opt) {        
    if (typeof opt=="undefined") {
      if ((typeof wrapper=="object")&&!("jquery" in wrapper)) {
        opt = wrapper;
        wrapper = false;        
      }
    }
    var ret = new NiceScrollArray();
    if (typeof opt=="undefined") opt = {};
    
    if (wrapper||false) {      
      opt.doc = $(wrapper);
      opt.win = $(this);
    }    
    var docundef = !("doc" in opt);   
    if (!docundef&&!("win" in opt)) opt.win = $(this);    
    
    this.each(function() {
      var nice = $(this).data('__nicescroll')||false;
      if (!nice) {
        opt.doc = (docundef) ? $(this) : opt.doc;
        nice = new NiceScrollClass(opt,$(this));        
        $(this).data('__nicescroll',nice);
      }
      ret.push(nice);
    });
    return (ret.length==1) ? ret[0] : ret;
  };
  
  window.NiceScroll = {
    getjQuery:function(){return jQuery}
  };
  
  if (!$.nicescroll) {
   $.nicescroll = new NiceScrollArray();
   $.nicescroll.options = _globaloptions;
  }
  
})( jQuery );
  
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('knobDirective', knobDirectiveFactory);
    /*******************************************************************************************************************************************************************/
    function knobDirectiveFactory() {

        return {
            restrict: 'EA',
            require: '?ngModel',

            link: function (scope, element, attrs, ngModel) {

              
               
                if (!ngModel) return; // do nothing if no ng-model
                ngModel.$render = function () {
                    scope.currentValue = ngModel.$viewValue;
                    $(element).val(scope.currentValue)
                    $(element).knob({
                        'min': 0,
                        'max': 100,
                        'readOnly': true,
                        'width': 50,
                        'height': 50,
                        'fgColor': '#5d6178',
                        
                        'draw' : function () { $(this.i).val(this.cv + '%'); }
                    

                    });

                };
              

             
                
            }
        }; 
    }

    /*******************************************************************************************************************************************************************************/

})(angular);

(function (angular) {
    'use strict';

loadingDirectiveFactory.$inject = ['$log'];
    angular.module('module.widgets')
      .directive('loadingDirective', loadingDirectiveFactory);

/*********************************************************************Weather****************************************************************************************************/
function loadingDirectiveFactory($log) {

    return {
        restrict: 'A',
        require: '?ngModel',
        link: function (scope, element, attrs, ngModel) {

            var _html = "<img style=\"width:50px;height:50px\" src=\"content/img/loaders/loading11.gif\">";
            var spinnerElement = $(_html).insertAfter(element);

            function setSpinnerState() {
                if (ngModel.$viewValue) {
                    element.attr("disabled", "disabled");
                    spinnerElement.show();
                }
                else {
                    spinnerElement.hide();
                    element.removeAttr("disabled");
                }
            }

            ngModel.$render = function () {

                setSpinnerState();
            };

            setSpinnerState();
        }
    };

}
})(angular);

(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    ngConfirmClickFactory.$inject = ['$log'];
    angular.module('module.widgets')
        .directive('ngConfirmClick', ngConfirmClickFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function ngConfirmClickFactory($log) {
        return {
            link: function (scope, element, attr) {
                var msg = attr.ngConfirmClick || "Are you sure?";
                var clickAction = attr.confirmedClick;
                
                element.bind('click', function (event) {
                    var retVal = prompt("Please write \"i want to delete\" : ", " I...");
                    if (window.confirm(msg)) {
                        if (retVal == "i want to delete") {
                            scope.$eval(clickAction)
                        } else {
                            toastr.error('You Wrong... ');
                        }
                        
                    }
                });
            }
        };


       
    }

    /*******************************************************************************************************************************************************************************/

})(angular);







var mod = angular.module('module.widgets');
mod.filter('range', function () {
    return function (input, total) {
        total = parseInt(total);

        for (var i = 0; i < total; i++) {
            input.push(i+1);
        }

        return input;
    };
});

(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('paging', paging);


    //////////////// JavaScript //////////////



    function paging() {

        return {

            restrict: 'EA',
            templateUrl: 'app/modules/module.widgets/paging/paging.html',
            scope: {
                comm: '='
            },
            controller: ['$scope', function ($scope) {

                $scope.menu = {
                 
                    'prev': false,
                    'forward': false
                
                }

                var totalPages = 0;
                var currentPage = 0;


                $scope.comm.SetCallbackDown(function (newPageNumber, pageSize, TotalItems) {

                    totalPages = Math.ceil(TotalItems / pageSize);
                    currentPage = newPageNumber;

                    firstLast();
                    $scope.list = build_list_of_pages();
                  
                });

                function changePage(page) {
                    firstLast();
                    if (0 < page && page <= totalPages) {

                        $scope.comm.CallbackUp(page);

                        return true;
                    }

                    return false;
                }

                function firstLast() {

                    if (currentPage == 1) {
                        $scope.menu.prev = true;
                       

                    }
                    else {
                        $scope.menu.prev = false;
                    }

                    if (currentPage >= totalPages) {
                        $scope.menu.forword = true;
                 

                    }
                    else {
                        $scope.menu.forword = false;
                    }
                }

                function build_list_of_pages() {
                    var listOfObjects = [];

                    if (totalPages < 5) {
                        for (var i = 1 ; i <= totalPages; i++) {

                            var singleObj = {}
                            singleObj['value'] = i;
                            if (i == currentPage) {
                                singleObj['type'] = 'active';
                            } else {
                                singleObj['type'] = '';
                            }

                            listOfObjects.push(singleObj);
                        }
                    }
                    else {
                        if (currentPage - 1 >= 0) {
                            if (currentPage - 1 >= 2) {   //two page before current page
                                var singleObj1 = {}
                                singleObj1['value'] = currentPage - 2;
                                singleObj1['type'] = '';
                                listOfObjects.push(singleObj1);

                                var singleObj2 = {}
                                singleObj2['value'] = currentPage - 1;
                                singleObj2['type'] = '';
                                listOfObjects.push(singleObj2);

                                var singleObj3 = {}
                                singleObj3['value'] = currentPage;
                                singleObj3['type'] = 'active';
                                listOfObjects.push(singleObj3);

                                if (currentPage + 1 <= totalPages) {
                                    var singleObj4 = {}
                                    singleObj4['value'] = currentPage + 1;
                                    singleObj4['type'] = '';
                                    listOfObjects.push(singleObj4);
                                }
                                if (currentPage + 2 <= totalPages) {
                                    var singleObj5 = {}
                                    singleObj5['value'] = currentPage + 2;
                                    singleObj5['type'] = '';
                                    listOfObjects.push(singleObj5);
                                }
                            }
                            if (currentPage - 1 == 1) {//one page before current page

                                var singleObj1 = {}
                                singleObj1['value'] = currentPage - 1;
                                singleObj1['type'] = '';
                                listOfObjects.push(singleObj1);

                                var singleObj2 = {}
                                singleObj2['value'] = currentPage;
                                singleObj2['type'] = 'active';
                                listOfObjects.push(singleObj2);

                                var singleObj3 = {}
                                singleObj3['value'] = currentPage + 1;
                                singleObj3['type'] = '';
                                listOfObjects.push(singleObj3);

                                var singleObj4 = {}
                                singleObj4['value'] = currentPage + 2;
                                singleObj4['type'] = '';
                                listOfObjects.push(singleObj4);

                                var singleObj5 = {}
                                singleObj5['value'] = currentPage + 3;
                                singleObj5['type'] = '';
                                listOfObjects.push(singleObj5);
                            }
                            if (currentPage - 1 == 0) {//no page before current page

                                var singleObj1 = {}
                                singleObj1['value'] = currentPage;
                                singleObj1['type'] = 'active';
                                listOfObjects.push(singleObj1);

                                var singleObj2 = {}
                                singleObj2['value'] = currentPage + 1;
                                singleObj2['type'] = '';
                                listOfObjects.push(singleObj2);

                                var singleObj3 = {}
                                singleObj3['value'] = currentPage + 2;
                                singleObj3['type'] = '';
                                listOfObjects.push(singleObj3);

                                var singleObj4 = {}
                                singleObj4['value'] = currentPage + 3;
                                singleObj4['type'] = '';
                                listOfObjects.push(singleObj4);

                                var singleObj5 = {}
                                singleObj5['value'] = currentPage + 4;
                                singleObj5['type'] = '';
                                listOfObjects.push(singleObj5);
                            }
                        }
                    }
                    return listOfObjects;
                }

                function prevPage() {

                    changePage(currentPage - 1);
                }

                function firstPage() {
                    changePage(1);
                }

                function lastPage() {

                    changePage(totalPages);
                }

                function forwardPage() {

                    changePage(currentPage + 1);

                }


                $scope.build_list_of_pages = build_list_of_pages;
                $scope.prevPage = prevPage;
                $scope.firstPage = firstPage;
                $scope.lastPage = lastPage;
                $scope.forwardPage = forwardPage;
                $scope.changePage = changePage;

            }]
        };
    
        
    }
})(angular);






/// <reference path="weatherSaving.html" />
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    progressFactory.$inject = ['$log'];
    angular.module('module.widgets')
        .directive('progress', progressFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function progressFactory($log) {

        return {
            restrict: 'EA',
          
            require: '?ngModel',
          
            controller: ['$scope', function ($scope) {

               
            }],
            link: function (scope, element, attrs, ngModel) {
               
                function progress(percent, $element) {
                    var progressBarWidth = percent * $element.width() / 100;
                    $element.find('div').animate({ width: progressBarWidth }, 500).html(percent + "%&nbsp;");
                }

                ngModel.$render = function () {
                    if (ngModel && ngModel.$viewValue) {
                     
                        progress(ngModel.$viewValue, element)
                    }
                };
            }
        };//return
    }

    /*******************************************************************************************************************************************************************************/

})(angular);

(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('readCondition', readConditionFactory);
    /*******************************************************************************************************************************************************************/
    function readConditionFactory() {

        return {
            restrict: 'EA',
            link: function (scope, element, attrs ) {


                check_param(attrs.param);
                attrs.$observe('param', function (val) {
                    check_param(val);
                });
                  
                function check_param(param) {
                    if (param == "false") { //read only
                        $(element).prop('readonly', true);
                      
                      
                    } else {
                        $(element).prop('readonly', false);
                        $(element).css("background-color", "white");
                    }
                }
                   

               




            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    selectOnClickFactory.$inject = ['$log'];
    angular.module('module.widgets')
        .directive('selectOnClick', selectOnClickFactory);
    /*******************************************************************************************************************************************************************/
    function selectOnClickFactory($log) {

        return {
            restrict: 'A',
            link: function (scope, element, attrs) {
                element.on('click', function () {
                    this.select();
                });
            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    speedFactory.$inject = ['$log'];
    angular.module('module.widgets')
        .directive('speed', speedFactory);
    /*******************************************************************************************************************************************************************/
    function speedFactory($log) {

        return {
            restrict: 'EA',
            require: '?ngModel',
            scope: {
                obj: '='
            },

            link: function (scope, element, attrs, ngModel) {
                var options;
                var data;
                var chart;

                if (!ngModel) return;
                ngModel.$render = function () {
                    if (chart != null) {
                        scope.val = ngModel.$viewValue;
                        data.setValue(0, 1, scope.val);
                        chart.draw(data, options);
                    }
            
                };
                //google.load("visualization", "1", { packages: ["gauge"] });
                google.load("visualization", "1", {packages: ["gauge"], "callback": drawChart });
                //google.setOnLoadCallback(function () {
                 
                //        drawChart()
                
                //});
             
                function drawChart() {
                  
                     data = google.visualization.arrayToDataTable([
                          ['Label', 'Value'],
                          [scope.obj.data.Label, scope.obj.data.Value]
                       
       
                   ]);

                    options = {
                        width: 400, height: scope.obj.options.height,
                        redFrom: scope.obj.options.redFrom, redTo: scope.obj.options.redTo,
                        yellowFrom: scope.obj.options.yellowFrom, yellowTo: scope.obj.options.yellowTo,
                        majorTicks: scope.obj.options.majorTicks,
                        backgroundColor: 'transparent',
                        minorTicks: scope.obj.options.minorTicks,
                        max: scope.obj.options.max,
                        min: scope.obj.options.min
                    };

                    chart = new google.visualization.Gauge(element[0]);

                    chart.draw(data, options);

               
                   
                  
                
                }







    
            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);

(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('timePicker2', timeDirectiveFactory);
    function timeDirectiveFactory() {

        return {
            restrict: 'EA',
            link: function (scope, element, attr) {
                var twelvehour = false;
                if (attr.param == "AMPM") {
                    twelvehour = true;
                }
                $(element).clockpicker({
                    autoclose: true,
                    twelvehour: twelvehour
                });
                element.bind("click", function () {
                    $(element).clockpicker('show');
                })

            }

        };//return
    }

})(angular);




(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.translate')
        .provider('timer', timer);


    //////////////// JavaScript //////////////

    function timer() {

        var _oldTime;
        var SecTimer;
      
        function _timeFinish() {

            clearTimeout(SecTimer)
            SecTimer = setTimeout(function () {
                
                window.location = MAIN_LINKS.LOGIN.link + "&returnUrl=" + encodeURIComponent(window.location.href);

            }, 1200000);

        }
        function _firstTimer() {


            SecTimer = setTimeout(function () {
                
                window.location = MAIN_LINKS.LOGIN.link + "&returnUrl=" + encodeURIComponent(window.location.href);

            }, 1200000);

        }



        return {
            $get: function () {


                //interface
                return {
                    oldTime: _oldTime,
                    timeFinish: _timeFinish,
                    firstTimer: _firstTimer




                };
            }
        }
    }
})(angular);






/**
 * TimeTo jQuery plug-in
 * Show countdown timer or realtime clock
 *
 * @author Alexey Teterin <altmoc@gmail.com>
 * @version 1.0.15
 * @license MIT http://opensource.org/licenses/MIT
 * @date 2014-01-17
 */
'use strict';

(function (factory) {
    if (typeof exports === 'object') {
        // CommonJS (Node)
        var jQuery = require('jquery');
        module.exports = factory(jQuery || $);
    } else if (typeof define === 'function' && define.amd) {
        // AMD
        define(['jquery'], factory);
    } else {
        // globals
        factory(jQuery || $);
    }
}(function ($) {

    var defaults = {
        callback: null,          // callback function for exec when timer out
        captionSize: 0,          // font-size by pixels for captions, if 0 then calculate automaticaly
        countdown: true,         // is countdown or real clock
        countdownAlertLimit: 10, // limit in seconds when display red background
        displayCaptions: false,  // display captions under digit groups
        displayDays: 0,          // display day timer, count of days digits
        displayHours: true,      // display hours
        fontFamily: 'Verdana, sans-serif',
        fontSize: 28,            // font-size of a digit by pixels
        lang: 'en',              // language of caption
        seconds: 0,              // timer's countdown value in seconds
        start: true,             // true to start timer immediately
        theme: 'white',          // 'white' or 'black' theme fo timer's view
        
        vals: [0, 0, 0, 0, 0, 0, 0, 0, 0],  // private, current value of each digit
        limits: [9, 9, 9, 2, 9, 5, 9, 5, 9],// private, max value of each digit
        iSec: 8,            // private, index of second digit
        iHour: 4,           // private, index of hour digit
        tickTimeout: 1000,  // timeout betweet each timer tick in miliseconds
        intervalId: null    // private
    };

    var methods = {
        start: function(sec) {
            if(sec) init.call(this, sec);
            var me = this,
                intervalId = setTimeout(function(){ tick.call(me); }, 1000);

            // save start time
            this.data('ttStartTime', (new Date()).getTime());
            this.data('intervalId', intervalId);
        },

        stop: function() {
            var data = this.data();

            if(data.intervalId){
                clearTimeout(data.intervalId);
                this.data('intervalId', null);
            }
            return data;
        },
        
        reset: function(sec){
            var data = methods.stop.call(this);

            this.find('div').css({ backgroundPosition: 'left center' });
            this.find('ul').parent().removeClass('timeTo-alert');

            if(typeof sec === "undefined") { sec = data.value; }
            init.call(this, sec, true);
        }
    };

    var dictionary = {
        en:{days:'days',   hours:'hours',  min:'minutes',  sec:'seconds'},
        ru:{days:'дней',   hours:'часов',  min:'минут',    sec:'секунд'},
        ua:{days:'днiв',   hours:'годин',  min:'хвилин',   sec:'секунд'},
        de:{days:'Tag',    hours:'Uhr',    min:'Minuten',  sec:'Secunden'},
        fr:{days:'jours',  hours:'heures', min:'minutes',  sec:'secondes'},
        sp:{days:'días',   hours:'reloj',  min:'minutos',  sec:'segundos'},
        it:{days:'giorni', hours:'ore',    min:'minuti',   sec:'secondi'},
        nl:{days:'dagen',  hours:'uren',   min:'minuten',  sec:'seconden'},
        no:{days:'dager',  hours:'timer',  min:'minutter', sec:'sekunder'},
        pt:{days:'dias',   hours:'horas',  min:'minutos',  sec:'segundos'}
    };
    
    if(typeof $.support.transition === 'undefined') {
        $.support.transition = (function(){
            var thisBody = document.body || document.documentElement,
                thisStyle = thisBody.style,
                support = thisStyle.transition !== undefined || thisStyle.WebkitTransition !== undefined || thisStyle.MozTransition !== undefined || thisStyle.MsTransition !== undefined || thisStyle.OTransition !== undefined;

            return support;
        })();
    }


    $.fn.timeTo = function(){
        var method, options = {};

        for(var i = 0, arg; arg = arguments[i]; ++i) {
            if(i == 0 && typeof arg === 'string') {
                method = arg;
            }
            else {
                if(typeof arg === 'object') {
                    if(typeof arg.getTime === 'function') {
                        options.timeTo = arg;
                    }
                    else {
                        options = $.extend(options, arg);
                    }
                }
                else {
                    if(typeof arg === 'function') {
                        options.callback = arg;
                    }
                    else {
                        var v = parseInt(arg, 10);
                        if(!isNaN(v)) {
                            options.seconds = v;
                        }
                    }
                }
            }
        }

        // set time for countdown to
        if(options.timeTo) {
            var time,
                now = (new Date()).getTime();

            if(options.timeTo.getTime) { // set time as date object
                time = options.timeTo.getTime();
            }
            else if(typeof options.timeTo === 'number') {  // set time as integer in millisec
                time = options.timeTo;
            }
            if(options.timeTo > now) {
                options.seconds = Math.floor((time - now) / 1000);
            }
        }else if(options.time || !options.seconds) {
            var time = options.time;

            if(!time) time = new Date();

            if(typeof time === 'object' && time.getTime) {
                options.seconds = time.getHours()*3600 + time.getMinutes()*60 + time.getSeconds();
                options.countdown = false;
            }
            else if(typeof time === 'string') {
                var tt = time.split(':'),
                    sec = 0, m = 1, t;

                while(t = tt.pop()) {
                    sec += t*m;
                    m *= 60;
                }
                options.seconds = sec;
                options.countdown = false;
            }
        }

        if(options.countdown !== false && options.seconds > 86400 && typeof options.displayDays === 'undefined') {
            var days = Math.floor(options.seconds / 86400);
            options.displayDays = days < 10 && 1 || days < 100 && 2 || 3;
        }
        else if(options.displayDays === true) {
            options.displayDays = 3;
        }
        else if(options.displayDays) {
            options.displayDays = options.displayDays > 0 ? Math.floor(options.displayDays) : 3;
        }

        return this.each(function() {
            var $this = $(this),
                data = $this.data(),
                i;


            if(data.intervalId) {
                clearInterval(data.intervalId);
                data.intervalId = null;
            }

            if(!data.vals || method === 'reset') { // new clock
                if(data.options) {
                    options = data.options;
                }
                data = $.extend(defaults, options);
                data.options = options;

                data.height = Math.round(data.fontSize * 100 / 93);
                data.width = Math.round(data.fontSize * .8 + data.height * .13);
                data.displayHours = !!(data.displayDays || data.displayHours);

                $this
                    .addClass('timeTo')
                    .addClass('timeTo-'+ data.theme)
                    .css({
                        fontFamily: data.fontFamily,
                        fontSize: data.fontSize +'px'
                    });

                var left = Math.round(data.height / 10),
                    ulhtml = '<ul style="left:'+ left +'px; top:-'+ data.height +'px"><li>0</li><li>0</li></ul></div>',
                    style = ' style="width:'+ data.width +'px; height:'+ data.height +'px;"',
                    dhtml1 = '<div class="first"'+ style +'>'+ ulhtml,
                    dhtml2 = '<div'+ style +'>'+ ulhtml,
                    dot2 = '<span>:</span>',
                    maxWidth = Math.round(data.width * 2 + 3),
                    captionSize = data.captionSize || Math.round(data.fontSize * 0.43),

                    thtml = (data.displayCaptions ?
                        (data.displayHours
                            ? '<figure style="max-width:'+ maxWidth +'px">$1<figcaption style="font-size:'+ captionSize +'px">'+ dictionary[data.lang].hours +'</figcaption></figure>'+ dot2
                            : '') +
                        '<figure style="max-width:'+ maxWidth +'px">$1<figcaption style="font-size:'+ captionSize +'px">'+ dictionary[data.lang].min +'</figcaption></figure>'+ dot2 +
                        '<figure style="max-width:'+ maxWidth +'px">$1<figcaption style="font-size:'+ captionSize +'px">'+ dictionary[data.lang].sec +'</figcaption></figure>'
                        : (data.displayHours ? '$1'+ dot2 : '') +'$1'+ dot2 +'$1'
                    ).replace(/\$1/g, dhtml1 + dhtml2);

                if(data.displayDays > 0) {
                    var marginRight = data.fontSize * 0.4,
                        dhtml = dhtml1;
                    for(i = data.displayDays - 1; i > 0; i--) {
                        dhtml += i === 1 ? dhtml2.replace('">', ' margin-right:'+ Math.round(marginRight) +'px">') : dhtml2;
                    }
                    thtml = (data.displayCaptions ?
                        '<figure style="width:'+ Math.round(data.width*data.displayDays + marginRight + 4) +'px">$1<figcaption style="font-size:'+ captionSize +'px; padding-right:'+ Math.round(marginRight) +'px">'+ dictionary[data.lang].days +'</figcaption></figure>'
                        : '$1').replace(
                            /\$1/, dhtml
                        ) + thtml;
                }
                $this.html(thtml);
            }
            else { // exists clock
                $.extend(data, options);
            }
            
            var $digits = $this.find('div');

            if($digits.length < data.vals.length) {
                var dif = data.vals.length - $digits.length,
                    vals = data.vals, limits = data.limits;

                data.vals = [];
                data.limits = [];
                for(i = 0; i < $digits.length; i++){
                    data.vals[i] = vals[dif + i];
                    data.limits[i] = limits[dif + i];
                }
                data.iSec = data.vals.length - 1;
                data.iHour = data.vals.length - 5;
            }
            data.sec = data.seconds;
            $this.data(data);
            
            if(method && methods[method]) {
                methods[ method ].call($this, data.seconds);
            }
            else if(data.start) {
                methods.start.call($this, data.seconds);
            }
            else {
                init.call($this, data.seconds);
            }
        });
    };


    function init(sec, force) {
        var data = this.data(),
            $digits = this.find('ul'),
            isInterval = false;

        if (!data.vals || $digits.length === 0) {
            return;
        }

        if(!sec) {
            sec = data.seconds;
        }

        if (data.intervalId) {
            isInterval = true;
            clearTimeout(data.intervalId);
        }

        var days = Math.floor(sec / 86400),
            rest = days * 86400,
            h = Math.floor((sec - rest) / 3600);

        rest += h * 3600;

        var m = Math.floor((sec - rest) / 60);
        
        rest += m * 60;
        
        var s = sec - rest,
            str = (days < 100 ? '0' + (days < 10 ? '0' : '') : '') + days + (h < 10 ? '0' : '') + h + (m < 10 ? '0' : '') + m + (s < 10 ? '0' : '') + s;

        for(var i = data.vals.length - 1, j = str.length - 1, v; i >= 0; i--, j--) {
            v = parseInt(str.substr(j, 1));
            data.vals[i] = v;
            $digits.eq(i).children().html(v);
        }
        if(isInterval || force) {
            var me = this;
            data.ttStartTime = Date.now();
            data.intervalId = setTimeout(function(){ tick.call(me); }, 1000);
            this.data('intervalId', data.intervalId);
        }
    }
        
    /**
     * Switch specified digit by digit index
     * @param {number} - digit index
     */
    function tick(digit) {
        var $digits = this.find('ul'),
            data = this.data();

        if(!data.vals || $digits.length == 0) {
            if(data.intervalId) {
                clearTimeout(data.intervalId);
                this.data('intervalId', null);
            }
            if(data.callback) {
                data.callback();
            }

            return;
        }
        if(digit == undefined) {
            digit = data.iSec;
        }

        var n = data.vals[digit],
            $ul = $digits.eq(digit),
            $li = $ul.children(),
            step = data.countdown ? -1 : 1;

        $li.eq(1).html(n);
        n += step;

        if(digit == data.iSec) {
            var tickTimeout = data.tickTimeout,
                timeDiff = (new Date()).getTime() - data.ttStartTime;

            data.sec += step;

            tickTimeout += Math.abs(data.seconds - data.sec) * tickTimeout - timeDiff;

            data.intervalId = setTimeout(function(){ tick.call(me); }, tickTimeout);
        }
        
        if(n < 0 || n > data.limits[digit]) {
            if(n < 0) {
                n = data.limits[digit];
                if(digit == data.iHour && data.displayDays > 0 && digit > 0 && data.vals[digit-1] == 0) // fix for hours when day changing
                    n = 3;
            }
            else {
                n = 0;
            }

            if(digit > 0) {
                tick.call(this, digit-1);
            }
        }
        //$ul.removeClass('transition');
        //$ul.css({top:"-" + data.height + "px"});
        $li.eq(0).html(n);
        
        var me = this;
        //*****************************************************
        var sound = document.getElementById("limitAudio");
        //******************************************************
        if($.support.transition) {
            $ul.addClass('transition');
            $ul.css({top:0});

            setTimeout(function() {
                $ul.removeClass('transition');
                $li.eq(1).html(n);
                $ul.css({top:"-"+ data.height +"px"});

                if(step > 0 || digit != data.iSec) {
                    return;
                }

                if(data.sec == data.countdownAlertLimit) {
                    $digits.parent().addClass('timeTo-alert');
                    sound.play();
                }

                if (data.sec === 0) {
                    sound.pause();
                    sound.currentTime = 0;
                    $digits.parent().removeClass('timeTo-alert');
                    
                    if(data.intervalId) {
                        clearTimeout(data.intervalId);
                        me.data('intervalId', null);
                    }

                    if(typeof data.callback === 'function') {
                        data.callback();
                    }
                }
            }, 410);
        }
        else {
            $ul.stop().animate({top:0}, 400, digit != data.iSec ? null : function() {
                $li.eq(1).html(n);
                $ul.css({top:"-"+ data.height +"px"});
                if(step > 0 || digit != data.iSec) {
                    return;
                }

                if(data.sec == data.countdownAlertLimit) {
                    $digits.parent().addClass('timeTo-alert');
                }
                else if(data.sec == 0) {
                    $digits.parent().removeClass('timeTo-alert');

                    if(data.intervalId) {
                        clearTimeout(data.intervalId);
                        me.data('intervalId', null);
                    }

                    if(typeof data.callback === 'function') {
                        data.callback();
                    }
                }
            });
        }
        data.vals[digit] = n;
        //this.data('vals', data.vals);
    }

    return jQuery;
    
}));

//$(document).ready(function () {
//    $('[data-toggle="tooltip"]').tooltip();
//});
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    phoneTooltipFactory.$inject = ['$filter'];
    angular.module('module.widgets')
        .directive('phoneTooltip', phoneTooltipFactory);
    /**************************************************************************************************************************************************************/
    function phoneTooltipFactory($filter) {



        return {
            restrict: 'EA',
            scope:{

            },

            link: function (scope, element, attrs, ngModel) {
                function detectmob() {
                    if (navigator.userAgent.match(/Android/i)
                    || navigator.userAgent.match(/webOS/i)
                    || navigator.userAgent.match(/iPhone/i)
                    || navigator.userAgent.match(/iPad/i)
                    || navigator.userAgent.match(/iPod/i)
                    || navigator.userAgent.match(/BlackBerry/i)
                    || navigator.userAgent.match(/Windows Phone/i)
                    ) {
                        return true;
                    }
                    else {
                        return false;
                    }
                }

                $(element).on({
                    "click": function (e) {

                       // var intViewportWidth = window.innerWidth;
                        if (detectmob()) {
                            scope.str = $filter('translate')(attrs.var1);

                            $("<textarea>")
                            .addClass('tool')
                            .text(scope.str)
                            .click(function () {
                                $(this).remove();
                            })
                            .insertBefore(element.parents('.panel'));

                        }
                     }
                    });
            
            }
        };
    }
    /*******************************************************************************************************************************************************************************/

})(angular);
angular.module('ngSimpleUpload', [])
    .directive('ngSimpleUpload', [function () {
        return {
            scope: {
                webApiUrl: '@',
                callbackFn: '=',
                callbackAn: '=',
                callbackProgress: '=',
                buttonId: '@'
            },
            link: function (scope, element, attrs) {
                function getCookie(cname) {
                    var name = cname + "=";
                    var ca = document.cookie.split(';');
                    for (var i = 0; i < ca.length; i++) {
                        var c = ca[i];
                        while (c.charAt(0) == ' ') c = c.substring(1);
                        if (c.indexOf(name) == 0) return c.substring(name.length, c.length);
                    }
                    return "";
                }
                // if button id value exists
                if (scope.buttonId) {
                    $('#' + scope.buttonId).on('click', function () {

                        // retrieves files from file input
                        var files = element[0].files;
                        // will not fire until file(s) are selected
                        if (files.length == 0) {
                            console.log('No files detected.');
                            return false;
                        }

                        Upload(files);
                    });
                }
                else {
                    // original code, trigger upload on change
                    element.on('change', function (evt) {


                        scope.callbackAn(true);



                        var files = evt.__files_ || (evt.target && evt.target.files);

                        Upload(files);

                        // removes file(s) from input
                        $(this).val('');
                    });
                }





                //************************************

                function progress(e) {

                    if (e.lengthComputable) {
                        var max = e.total;
                        var current = e.loaded;

                        var Percentage = (current * 100) / max;
                        Percentage = parseInt(Percentage);
                        console.log(Percentage);


                        if (Percentage <= 99) {
                            scope.callbackProgress(Percentage);
                        }
                    }
                }
                //**

                function Upload(files) {
                    var fd = new FormData();
                    angular.forEach(files, function (v, k) {
                        fd.append('file', files[k]);
                    });

                    return $.ajax({
                        type: 'POST',
                        url: scope.webApiUrl,
                        headers: { 'Authorization': 'Bearer ' + getCookie('AccessTokenAccount') },
                        data: fd,
                        xhr: function () {
                            var myXhr = $.ajaxSettings.xhr();
                            if (myXhr.upload) {
                                myXhr.upload.addEventListener('progress', progress, false);
                            }
                            return myXhr;
                        },
                        async: true,
                        cache: false,
                        contentType: false,
                        processData: false
                    }).done(function (d) {
                        // callback function in the controller
                        scope.callbackFn(d);
                    }).fail(function (x) {
                        console.log(x);
                    });


                }
            }
        }
    }]);

(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.GSI.Device')
        .directive('generalLogs', ['$filter', generalLogsFactory]);
    /***********************************************************************************************************************************************************************/
    function generalLogsFactory() {
        return {
            restrict: 'EA',
            //require: '?ngModel',
            templateUrl: 'app/modules.devices/GSI.Device/generalLogs/generalLogs.html',

            controller: ['$scope', '$rootScope', 'siteProxy', '$filter', '$state',
                function ($scope, $rootScope, siteProxy, $filter, $state) {
                    //*********************************
                    $scope.CostomDate = {
                        'startUnix': '',
                        'endUnix': '',
                        'startStr': '',
                        'endStr': ''
                    };
                    //*********************************
                    //***********************UnixTime(Outer)****************
                    $scope.UnixTime = function (local, param) {
                        var unixInt = parseInt(local);
                        var str = $filter('date')(local, 'mediumDate');
                        if (param == 0) {
                            $scope.CostomDate.startStr = str;
                            $scope.CostomDate.startUnix = translate.fullDateStringToUnixServer(str, "00:00")
                        } else {
                            $scope.CostomDate.endStr = str;
                            $scope.CostomDate.endUnix = translate.fullDateStringToUnixServer(str, "00:00")
                        }
                    }
                    //*******************************************

                    $scope.generalLogs = [
                        { "No": 1, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08",generalLog:"SD Card", Info: false, Message: "bla bla bla" },
                        { "No": 2, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08", generalLog: "SD Card", Info: false, Message: "bla bla bla" },
                        { "No": 3, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08", generalLog: "SD Card", Info: false, Message: "bla bla bla" },
                        { "No": 4, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08", generalLog: "SD Card", Info: true, Message: "bla bla bla" },
                        { "No": 5, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08", generalLog: "SD Card", Info: true, Message: "bla bla bla" },
                        { "No": 6, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08", generalLog: "SD Card", Info: false, Message: "bla bla bla" },
                        { "No": 7, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08", generalLog: "SD Card", Info: false, Message: "bla bla bla" },
                        { "No": 8, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08", generalLog: "SD Card", Info: false, Message: "bla bla bla" },
                        { "No": 9, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08", generalLog: "SD Card", Info: false, Message: "bla bla bla" },
                        { "No": 10, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08", generalLog: "SD Card", Info: true, Message: "bla bla bla" },
                        { "No": 11, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08", generalLog: "SD Card", Info: false, Message: "bla bla bla" },
                        { "No": 12, StartTime: "5/1/2016 12:00:00 AM", LastData: "22/7/16 12:00:00 AM", Duration: "1 day 20:12:08", generalLog: "SD Card", Info: false, Message: "bla bla bla" },
                    ]


                    $scope.Info = [
                        { No: 1, Date: "5/1/2016 12:00:00 AM", GeneralLogs: "Unit Logs Recived Succesfully", Message: "Alert Loger . Record 1 (5/1/2016 12:00:00 AM)" },
                        { No: 2, Date: "5/1/2016 12:00:00 AM", GeneralLogs: "Unit Logs Recived Succesfully", Message: "Alert Loger . Record 1 (5/1/2016 12:00:00 AM)" },
                        { No: 3, Date: "5/1/2016 12:00:00 AM", GeneralLogs: "Unit Logs Recived Succesfully", Message: "Alert Loger . Record 1 (5/1/2016 12:00:00 AM)" },
                        { No: 4, Date: "5/1/2016 12:00:00 AM", GeneralLogs: "Unit Logs Recived Succesfully", Message: "Alert Loger . Record 1 (5/1/2016 12:00:00 AM)" },
                        { No: 5, Date: "5/1/2016 12:00:00 AM", GeneralLogs: "Unit Logs Recived Succesfully", Message: "Alert Loger . Record 1 (5/1/2016 12:00:00 AM)" },
                        { No: 6, Date: "5/1/2016 12:00:00 AM", GeneralLogs: "Unit Logs Recived Succesfully", Message: "Alert Loger . Record 1 (5/1/2016 12:00:00 AM)" },
                        { No: 7, Date: "5/1/2016 12:00:00 AM", GeneralLogs: "Unit Logs Recived Succesfully", Message: "Alert Loger . Record 1 (5/1/2016 12:00:00 AM)" },
                        { No: 8, Date: "5/1/2016 12:00:00 AM", GeneralLogs: "Unit Logs Recived Succesfully", Message: "Alert Loger . Record 1 (5/1/2016 12:00:00 AM)" },
                        { No: 9, Date: "5/1/2016 12:00:00 AM", GeneralLogs: "Unit Logs Recived Succesfully", Message: "Alert Loger . Record 1 (5/1/2016 12:00:00 AM)" },
                    ]


                }],
            link: function (scope, element, attrs) {

                //if (!ngModel) return;
                //ngModel.$render = function () {

                //    scope.deviceId = ngModel.$viewValue;


                //};

            }

        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);








(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.GSI.Device')
        .directive('gsiOnline', ['$filter', gsiOnlineDFactory]);
    /***********************************************************************************************************************************************************************/
    function gsiOnlineDFactory($filter) {
        return {
            restrict: 'EA',
            require: '?ngModel',
            templateUrl: 'app/modules.devices/GSI.Device/online/GSI_Online.html',

            controller: ['$scope', '$rootScope', 'siteProxy', '$filter', '$state',
                function ($scope, $rootScope, siteProxy, $filter, $state) {
                    $scope.goToSquare = function () {
                        $state.go('site.preview.squares');
                    }


                }],
            link: function (scope, element, attrs, ngModel) {

                if (!ngModel) return;
                ngModel.$render = function () {

                    scope.deviceId = ngModel.$viewValue;
                    

                };

            }

        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);








(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.GSI.Device')
        .directive('hanukiya', ['$filter', hanukiyaDFactory]);
    /***********************************************************************************************************************************************************************/
    function hanukiyaDFactory($filter) {
        return {
            restrict: 'EA',
            templateUrl: 'app/modules.devices/GSI.Device/online/hanukiya.html',

            controller: ['$scope', '$rootScope', 'siteProxy', '$filter', '$state',
                function ($scope, $rootScope, siteProxy, $filter, $state) {
                    


                }],
            link: function (scope, element, attrs, ngModel) {

                

            }

        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);







/// <reference path="GSI_Programs.html" />

(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.GSI.Device')
        .directive('irrigationProgram', irrigationProgramFactory);



    function irrigationProgramFactory() {
        return {
            restrict: 'EA',

            templateUrl: 'app/modules.devices/GSI.Device/programs/GSI_Programs.html',

            controller: ['$scope', function ($scope) {
               
                var heigthFactor = 0;
                $(function () {
                    $("#slider-range-max").slider({
                        range: "max",
                        min: 0,
                        max: 59,
                        value: 1,
                        slide: function (event, ui) {
                            $("#amount").val(ui.value);
                            $('.programTable tbody tr').css('height', (ui.value * 5)+35);
                            heigthFactor = ui.value;
                            createValvesElements();
                        }
                    });
                    $("#amount").val($("#slider-range-max").slider("value"));
                });
                //*******************************yoman setting**************************************************************
                $scope.scheduling = {
                    state: "Weekly",
                    weekly:{
                        days: [{ num: 0, des: "Sun", state: true }, { num: 1, des: "Mon", state: false }, { num: 2, des: "Tue", state: true }, { num: 3, des: "Wed", state: true }, { num: 4, des: "Thu", state: true }, { num: 5, des: "Fri", state: true }, { num: 6, des: "Sat", state: true }]
                    },
                    cyclic: {
                        date: 1452067381081,
                        daysInterval:2
                    }

                }


                $scope.startTimes = {
                    state: "start",
                    starts: [{time:1452067381081},{time:1452067381081},{time:1452067381081},{time:1452067381081}],
                    intervals: {
                        start:{
                            time:1452067381081,
                            isOff:true
                        },
                        cycles: 5,
                        interval:3600
                    }

                }

                $scope.valves = {
                    currentMethod: 0,
                    list: [
                            { valve: 1, duration: 900, quantity: 2, im: 0, mm: 0 },
                            { valve: 2, duration: 900, quantity: 2, im: 0, mm: 0 },
                            { valve: 3, duration: 900, quantity: 2, im: 0, mm: 0 },
                            { valve: 4, duration: 900, quantity: 2, im: 0, mm: 0 },
                            { valve: 5, duration: 900, quantity: 2, im: 0, mm: 0 },
                            { valve: 6, duration: 900, quantity: 2, im: 0, mm: 0 },
                            { valve: 7, duration: 900, quantity: 2, im: 0, mm: 0 },
                            { valve: 8, duration: 900, quantity: 2, im: 0, mm: 0 },
                            { valve: 9, duration: 900, quantity: 2, im: 0, mm: 0 },
                            { valve: 10, duration: 900, quantity: 2, im: 0, mm: 0 },
                            { valve: -1, duration: 900, quantity: 2, im: 0, mm: 0 },
                            { valve: -1, duration: 900, quantity: 2, im: 0, mm: 0 },
                    ]
                }

                //**************************************yoman************************************************
                $scope.time = ["00:00", "00:30", "01:00", "01:30", "02:00", "02:30", "03:00", "03:30", "04:00", "04:30", "05:00", "05:30", "06:00", "06:30", "07:00", "07:30", "08:00", "08:30", "09:00", "09:30", "10:00", "10:30", "11:00", "11:30", "12:00", "12:30", "13:00", "13:30", "14:00", "14:30", "15:00", "15:30", "16:00", "16:30", "17:00", "17:30", "18:00", "18:30", "19:00", "19:30", "20:00", "20:30", "21:00", "21:30", "22:00", "22:30", "23:00", "23:30", "24:00"];
                $scope.timeMili = [0, 1800, 3600, 5400, 7200, 9000, 10800, 12600, 14400, 16200, 18000, 19800, 21600, 23400, 25200, 27000, 28800, 30600, 32400, 34200, 36000, 37800, 39600, 41400, 43200, 45000, 46800, 48600, 50400, 52200, 54000, 55800, 57600, 59400, 61200, 63000, 64800, 66600, 68400, 70200, 72000, 73800, 75600, 77400, 79200, 81000, 82800, 84600];
                $scope.days=[{ date: "04", day: 0, name: "Sun" }, { date: "05", day: 1, name: "Mon" }, { date: "06", day: 2, name: "Tue" }, { date: "07", day: 3, name: "Wed" }, { date: "08", day: 4, name: "Thu" }, { date: "09", day: 5, name: "Fri" }, { date: "10", day: 6, name: "Sat" }];
                $scope.records = [{ day: 0, program: 'A', start: 1500, valves: [{ name: 's1', duration: 900, time: 1500 }, { name: 's2', duration: 900, time: 2400 }, { name: 's3', duration: 900, time: 3300 }, { name: 's4', duration: 900, time: 4200 }, { name: 's5', duration: 900, time: 5100 }, { name: 's6', duration: 900, time: 6000 }, { name: 's7', duration: 900, time: 6900 }, { name: 's8', duration: 900, time: 7800 }, { name: 's9', duration: 900, time: 8700 }] },
                                  { day: 1, program: 'A', start:19000, valves: [{ name: 's1', duration: 900, time: 19900 }, { name: 's2', duration: 900, time: 21800 }, { name: 's3', duration: 900, time: 22700 }, { name: 's4', duration: 900, time: 23600 }, { name: 's5', duration: 900, time: 24500 }, { name: 's6', duration: 900, time: 25400 }, { name: 's7', duration: 900, time: 26300 }, { name: 's8', duration: 900, time: 27200 }, { name: 's9', duration: 900, time: 28100 }] },
                                  { day: 2, program: 'B', start: 6500, valves: [{ name: 's1', duration: 900, time: 6500 }, { name: 's2', duration: 900, time: 7400 }, { name: 's3', duration: 900, time: 8300 }, { name: 's4', duration: 900, time: 9200 }, { name: 's5', duration: 900, time: 10100 }, { name: 's6', duration: 900, time: 11000 }, { name: 's7', duration: 900, time: 11900 }, { name: 's8', duration: 900, time: 12800 }, { name: 's9', duration: 900, time: 13700 }] },
                                  { day: 3, program: 'B', start: 6500, valves: [{ name: 's1', duration: 900, time: 6500 }, { name: 's2', duration: 900, time: 7400 }, { name: 's3', duration: 900, time: 8300 }, { name: 's4', duration: 900, time: 9200 }, { name: 's5', duration: 900, time: 10100 }, { name: 's6', duration: 900, time: 11000 }, { name: 's7', duration: 900, time: 11900 }, { name: 's8', duration: 900, time: 12800 }, { name: 's9', duration: 900, time: 13700 }] },
                                  { day: 4, program: 'B', start: 6500, valves: [{ name: 's1', duration: 900, time: 6500 }, { name: 's2', duration: 900, time: 7400 }, { name: 's3', duration: 900, time: 8300 }, { name: 's4', duration: 900, time: 9200 }, { name: 's5', duration: 900, time: 10100 }, { name: 's6', duration: 900, time: 11000 }, { name: 's7', duration: 900, time: 11900 }, { name: 's8', duration: 900, time: 12800 }, { name: 's9', duration: 900, time: 13700 }] },
                                  { day: 5, program: 'B', start: 6500, valves: [{ name: 's1', duration: 900, time: 6500 }, { name: 's2', duration: 900, time: 7400 }, { name: 's3', duration: 900, time: 8300 }, { name: 's4', duration: 900, time: 9200 }, { name: 's5', duration: 900, time: 10100 }, { name: 's6', duration: 900, time: 11000 }, { name: 's7', duration: 900, time: 11900 }, { name: 's8', duration: 900, time: 12800 }, { name: 's9', duration: 900, time: 13700 }] },
                                  { day: 6, program: 'B', start: 6500, valves: [{ name: 's1', duration: 900, time: 6500 }, { name: 's2', duration: 900, time: 7400 }, { name: 's3', duration: 900, time: 8300 }, { name: 's4', duration: 900, time: 9200 }, { name: 's5', duration: 900, time: 10100 }, { name: 's6', duration: 900, time: 11000 }, { name: 's7', duration: 900, time: 11900 }, { name: 's8', duration: 900, time: 12800 }, { name: 's9', duration: 900, time: 13700 }] }

                ];

                //******************************************************************************************
                $scope.getColor = function(s) {
                    switch (s) {
                        case 's1': return '#9aa99b';
                            break;
                        case 's2': return '#71a795';
                            break;
                        case 's3': return '#65a7c4';
                            break;
                        case 's4': return '#5680b5';
                            break;
                        case 's5': return '#6c6ca4';
                            break;
                        case 's6': return '#84709b';
                            break;
                        case 's7': return '#847484';
                            break;
                        case 's8': return '#dd8c4f';
                            break;
                        case 's9': return '#c6705e';
                            break;
                        case 's10': return '#aa6d56';
                            break;
                        case 's11': return '#a06d97';
                            break;
                        case 's12': return '#944080';
                            break;
                        case 's13': return '#a62e69';
                            break;
                        case 's14': return '#b79bc1';
                            break;
                        case 's15': return '#b77080';
                            break;
                        case 's16': return '#dddb5b';
                            break;
                        case 's17': return '#c6aa5e';
                            break;
                        case 's18': return '#aaa856';
                            break;
                        case 's19': return '#86acb5';
                            break;
                        case 's20': return '#948180';
                            break;
                        case 's21': return '#a68469';
                            break;
                        case 's22': return '#b7885e';
                            break;
                        case 's23': return '#b7acb7';
                            break;
                        case 's24': return '#bfbd8e';
                            break;

                    }

                }
                //*****************************************************************************************
                function createValvesElements() {

                   


                    var arr = [0, 0, 0, 0, 0, 0, 0]
                    for (var i = 0; i < $scope.records.length; i++) {
                        if (document.getElementById('record' + i)) {
                            $('#record' + i).remove();

                        }



                        var mainDiv = document.createElement("Div");
                        mainDiv.id = 'record' + i;
                        mainDiv.style.position = 'absolute';//***************************************
                        mainDiv.style.border = '1px solid grey';
                        mainDiv.style.padding = '2px';
                        mainDiv.style.borderRadius = '6px';

                        const mainDivWIDTH = 70;
                        mainDiv.style.width = mainDivWIDTH + "px";
                        mainDiv.style.marginLeft = ((mainDivWIDTH + 7) * arr[$scope.records[i].day]) + 'px';
                        arr[$scope.records[i].day]++;
                        var programDiv = document.createElement("Div");
                        programDiv.style.backgroundColor = 'white';
                        programDiv.style.width = '30px';
                        programDiv.style.height = '20px';
                        programDiv.style.float = 'right';
                        programDiv.style.border = '1px solid gray';
                        programDiv.style.paddingLeft = '10px';
                        programDiv.innerHTML = $scope.records[i].program;
                        mainDiv.appendChild(programDiv);

                        var valvesDiv = document.createElement("Div");


                        for (var j = 0; j < $scope.records[i].valves.length; j++) {
                            var rowHeigth = (heigthFactor * 5) + 35;
                            $scope.records[i].valves[j].height = (($scope.records[i].valves[j].duration / 60) / 30) * rowHeigth + 'px';
                            var subDiv = document.createElement("Div");
                            var spanDiv = document.createElement("Span");
                            spanDiv.innerHTML = $scope.records[i].valves[j].name;
                            spanDiv.style.marginLeft = '7px';
                            spanDiv.style.verticalAlign = '-webkit-baseline-middle';
                            spanDiv.style.color = 'white';
                            subDiv.appendChild(spanDiv);

                            subDiv.style.height = $scope.records[i].valves[j].height;
                            subDiv.style.width = mainDivWIDTH-3+'px';
                            var time = convertUnixToTime($scope.records[i].valves[j].time).toLocaleTimeString().replace("/.*(\d{2}:\d{2}:\d{2}).*/", "$1");
                            subDiv.setAttribute("data-toggle", "tooltip");
                            subDiv.setAttribute("title", "Start Time: " + time + " Duration: " + $scope.records[i].valves[j].duration / 60 + " Min");
                            subDiv.style.backgroundColor = $scope.getColor($scope.records[i].valves[j].name);

                            valvesDiv.appendChild(subDiv);
                        }
                        mainDiv.appendChild(valvesDiv);
                        recordLocation(mainDiv, $scope.records[i])

                        for (var j = 0; j < arr.length; j++) {
                            var elem = document.getElementById('PITH' + j).style.minWidth = arr[j] * (mainDivWIDTH + 7) + 'px';

                        }

                    }
                    //  recordLocation(ctx, $scope.records[0])

                }
                //*****************************************************************************************
                function recordLocation(Div, record) {
                    
                    var start = record.start;
                    var index = 0;
                    var value = 0;
                    for (var i = 0; i < $scope.timeMili.length; i++) {
                        if ($scope.timeMili[i] > start) {
                           
                            index = i-1;
                            
                           
                            break;
                        }
                    }
                    var rowHeigth = (heigthFactor * 5) + 35;
                    start = start % 1800;
                    var offsetTop =Math.round(start /1800  * rowHeigth);
                    var fatherDivString = 'PI' + index.toString() + record.day.toString();
                    var fatherDivObject = angular.element('#' + fatherDivString);


                    Div.style.marginTop = offsetTop + 'px';
                    fatherDivObject.append(Div);

                }

                //*****************************************************************************************
                var myVar = setTimeout(function () {

                    //var canvas = document.createElement('canvas');

                    //canvas.id = "CursorLayer";
                    //canvas.width = 100;
                    //canvas.height = 100;
                    //canvas.style.zIndex = 8;
                    //canvas.style.position = "absolute";
                    //canvas.style.background = "black";
                    //canvas.style.border = "1px solid";
                    //var el = document.getElementById('PI03');
                    //el.appendChild(canvas);

                    createValvesElements();
                }, 100);
                //******************************************************************************************
                function stringToUnix(sec) { //only for clock(write) not for date

                    if (sec.indexOf("M") > -1) {
                        var n = sec.indexOf("M");
                        sec = sec.insertAt(n - 1, " ");
                    }
                    var time = new Date("October 13, 2014" + " " + sec);
                    return time.getSeconds() + (60 * time.getMinutes()) + (60 * 60 * time.getHours());
                };
                //******************************************************************************************
                function convertUnixToTime(millisecondsMidnight) {    //only for clock(read) not for date

                    var d = new Date(0);
                    var minutes = millisecondsMidnight / 60;
                    d.setHours(minutes / 60);
                    var minutes = minutes % 60
                    d.setMinutes(minutes);
                    if (minutes % 1 === 0) {
                        d.setSeconds(0);
                    } else {
                        minutes = Math.abs(minutes); // Change to positive
                        var decimal = (minutes - Math.floor(minutes))*60
                        d.setSeconds(decimal);
                    }
                    
                    return d;
                };
                //*********************************************************************************************

            }],
            link: function (scope, element, attrs, ngModel) {



            }




        };

    }
})(angular);

    /*******************************************************************************************************************************************************************************/

angular.module("module.GSI.Device.Settings", [
     "ui.router"
    , "module.widgets"
    , "colorpicker.module"
    , "module.httpProxies"])
.config(['$stateProvider', function ($stateProvider) {
    $stateProvider
    .state('device.GSI_device.settings', {
        url: '/settings',
        views: {
            '': {
                templateUrl: 'app/modules.devices/GSI.Device/settings/allSettings.html',
                controller: ['$scope', '$stateParams', '$state', function ($scope, $stateParams, $state) {
                    $scope.deviceId = $stateParams.deviceId;
                    $scope.goTo = function (action) {

                        //fixLoadingOn(action);
                        switch (action) {
                            case "Alerts":
                                $state.go('device.GSI_device.settings.alerts');
                                break;
                            case "Units":

                                $state.go('device.GSI_device.settings.unit');
                                break;
                            case "Stations":
                                $state.go('device.GSI_device.settings.stations');
                                break;
                        
                        }
                    }
                    $("#splash-page").css("display", "none");
                }
                ]
            }
        }
    })
   .state('device.GSI_device.settings.alerts', {
       url: '/alerts',
       views: {
           '': {
               template: '<div alerts-settings></div>',
               controller: ['$scope', '$stateParams', function ($scope, $stateParams) {
                   $scope.deviceId = $stateParams.deviceId;

               }
               ]
           }
       }
   })
    .state('device.GSI_device.settings.stations', {
        url: '/stations',
        views: {
            '': {
                template: '<div station-settings></div>',
                controller: ['$scope', '$stateParams', function ($scope, $stateParams) {
                    $scope.deviceId = $stateParams.deviceId;

                }
                ]
            }
        }
    })
    .state('device.GSI_device.settings.unit', {
        url: '/unit',
        views: {
            '': {
                template: '<div unit-settings></div>',
                controller: ['$scope', '$stateParams', function ($scope, $stateParams) {
                    $scope.deviceId = $stateParams.deviceId;

                }
                ]
            }
        }
    })
   

}]);

(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.GSI.Device')
        .directive('status', ['$filter', statusFactory]);
    /***********************************************************************************************************************************************************************/
    function statusFactory($filter) {
        return {
            restrict: 'EA',
            templateUrl: 'app/modules.devices/GSI.Device/status/status.html',

            controller: ['$scope', '$rootScope', 'siteProxy', '$filter', '$state',
                function ($scope, $rootScope, siteProxy, $filter, $state) {
                    $scope.isLogAlert = false;
                    $scope.irrigation = [
                        { No: 1, Date: "1.1.1990", StartTime: "07:00", EndTime: "08:45", Program: "Program-A",Station:"10", RunTime: "1:45", WaterQuantity: "", AverageFlow: "0.0 m3/h", FertilizerQuantity: "", Comment: "" },
                        { No: 2, Date: "1.1.1990", StartTime: "07:00", EndTime: "08:45", Program: "Program-A", Station: "10", RunTime: "1:45", WaterQuantity: "", AverageFlow: "0.0 m3/h", FertilizerQuantity: "", Comment: "" },
                        { No: 3, Date: "1.1.1990", StartTime: "07:00", EndTime: "08:45", Program: "Program-A", Station: "10", RunTime: "1:45", WaterQuantity: "", AverageFlow: "0.0 m3/h", FertilizerQuantity: "", Comment: "" },
                        { No: 4, Date: "1.1.1990", StartTime: "07:00", EndTime: "08:45", Program: "Program-A", Station: "10", RunTime: "1:45", WaterQuantity: "", AverageFlow: "0.0 m3/h", FertilizerQuantity: "", Comment: "" },
                        { No: 5, Date: "1.1.1990", StartTime: "07:00", EndTime: "08:45", Program: "Program-A", Station: "10", RunTime: "1:45", WaterQuantity: "", AverageFlow: "0.0 m3/h", FertilizerQuantity: "", Comment: "" },
                        { No: 6, Date: "1.1.1990", StartTime: "07:00", EndTime: "08:45", Program: "Program-A", Station: "10", RunTime: "1:45", WaterQuantity: "", AverageFlow: "0.0 m3/h", FertilizerQuantity: "", Comment: "" },
                        { No: 7, Date: "1.1.1990", StartTime: "07:00", EndTime: "08:45", Program: "Program-A", Station: "10", RunTime: "1:45", WaterQuantity: "", AverageFlow: "0.0 m3/h", FertilizerQuantity: "", Comment: "" },
                        { No: 8, Date: "1.1.1990", StartTime: "07:00", EndTime: "08:45", Program: "Program-A", Station: "10", RunTime: "1:45", WaterQuantity: "", AverageFlow: "0.0 m3/h", FertilizerQuantity: "", Comment: "" },
                        { No: 9, Date: "1.1.1990", StartTime: "07:00", EndTime: "08:45", Program: "Program-A", Station: "10", RunTime: "1:45", WaterQuantity: "", AverageFlow: "0.0 m3/h", FertilizerQuantity: "", Comment: "" },
                        { No: 10, Date: "1.1.1990", StartTime: "07:00", EndTime: "08:45", Program: "Program-A", Station: "10", RunTime: "1:45", WaterQuantity: "", AverageFlow: "0.0 m3/h", FertilizerQuantity: "", Comment: "" }

                    ]

                    $scope.alerts = [
                        { No: 1, Date: "1.1.1990  12:55:00",AlertType:"No Water Flow", Program: "Program-A", Station: "10", ActualFlow: "0.0 m3/h", NominalFlow: "0.0 m3/h", WatherQuantity: "", Comment: "" },
                        { No: 2, Date: "1.1.1990  12:55:00", AlertType: "No Water Flow", Program: "Program-A", Station: "10", ActualFlow: "0.0 m3/h", NominalFlow: "0.0 m3/h", WatherQuantity: "", Comment: "" },
                        { No: 3, Date: "1.1.1990  12:55:00", AlertType: "No Water Flow", Program: "Program-A", Station: "10", ActualFlow: "0.0 m3/h", NominalFlow: "0.0 m3/h", WatherQuantity: "", Comment: "" },
                        { No: 4, Date: "1.1.1990  12:55:00", AlertType: "No Water Flow", Program: "Program-A", Station: "10", ActualFlow: "0.0 m3/h", NominalFlow: "0.0 m3/h", WatherQuantity: "", Comment: "" },
                        { No: 5, Date: "1.1.1990  12:55:00", AlertType: "No Water Flow", Program: "Program-A", Station: "10", ActualFlow: "0.0 m3/h", NominalFlow: "0.0 m3/h", WatherQuantity: "", Comment: "" },
                        { No: 6, Date: "1.1.1990  12:55:00", AlertType: "No Water Flow", Program: "Program-A", Station: "10", ActualFlow: "0.0 m3/h", NominalFlow: "0.0 m3/h", WatherQuantity: "", Comment: "" },
                        { No: 7, Date: "1.1.1990  12:55:00", AlertType: "No Water Flow", Program: "Program-A", Station: "10", ActualFlow: "0.0 m3/h", NominalFlow: "0.0 m3/h", WatherQuantity: "", Comment: "" },
                        { No: 8, Date: "1.1.1990  12:55:00", AlertType: "No Water Flow", Program: "Program-A", Station: "10", ActualFlow: "0.0 m3/h", NominalFlow: "0.0 m3/h", WatherQuantity: "", Comment: "" }
                        


                    ]


                    //*******************************
                    
                    $('#GsiDeviceStatusdragButton').mousedown(function (e) {
                        e.preventDefault();

                        Statusdragbar = true;

                    });

                }],
            link: function (scope, element, attrs, ngModel) {

               

            }

        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);








(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.device')
        .directive('activateZones', activateZonesFactory);
    /*********************************************************************************************************************************************************************/
    function activateZonesFactory() {
        return {
            restrict: 'EA',
            require: '?ngModel',
            templateUrl: 'app/modules.devices/XCI.Device/activateZones.html',
            controller: ['$scope', '$window', 'baseProxy', 'deviceProxy', 'zoneProxy', 'mainRouter', function ($scope, $window, baseProxy, deviceProxy, zoneProxy, mainRouter) {
              
                $scope.getZonesActivateList = function (deviceId) {
             
                    deviceProxy.getZonesActivateList(deviceId)
                        .success(function (data, status, headers, config) {
                            $scope.zonesList = data.body;
                        }).error(function (data, status, headers, config) {
                      
                    });
                }
          
                //************************************************************
                $scope.switch = function (isOne) {
                   
                    isOne.tb.isEnabled = !isOne.tb.isEnabled;
                    deviceProxy.activateZone($scope.deviceId, isOne.tb)
                    .success(function (data, status, headers, config) {
                        mainRouter.callkey("refreshTable", {});
                        toastr.success('Changes Saves', 'Success!');
                    }).error(function (data, status, headers, config) {
                        toastr.error($filter('translate')('toastrErrMsgGet'));
                    });
                }
                //**************************************************************
            }
           
            ],
            link: function (scope, element, attr, ngModel) {

                if (!ngModel) return; // do nothing if no ng-model
                ngModel.$render = function () {
                    scope.deviceId = ngModel.$viewValue;
                    scope.getZonesActivateList(ngModel.$viewValue)
                };
               

            }
       
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);







angular.module("module.XCI.zones", [
     "ui.router"
     , "ngSimpleUpload"
    , "module.widgets"
    , "colorpicker.module"
    , "module.httpProxies"])
.config(['$stateProvider', function ($stateProvider) {
    $stateProvider

    .state('device.XCI_device.zones', {
        url: '/zones/:zoneId',
        views: {
            'root@': {
                templateUrl: 'app/modules.devices/XCI.Device/module.XCI.zone/XCI.zone.html',
                controller: ['$scope', '$stateParams', '$state', 'siteProxy','baseProxy', 'zoneProxy', function ($scope, $stateParams, $state, siteProxy,baseProxy, zoneProxy) {
                    $scope.deviceId = $stateParams.projectId;
                    $scope.siteId = $stateParams.siteId;
                    $scope.deviceId = $stateParams.deviceId;
                    $scope.zoneId = $stateParams.zoneId;
                    baseProxy.Global.data.serverXci + '/Admin/Zone'
                    $scope.imgUrl = baseProxy.Global.data.serverXci + '/Admin/Zone/' + $scope.deviceId + "/" + $scope.zoneId + "/ImageUpload";
                  
                    
                    siteProxy.GetDeviceInfo($stateParams.deviceId)
                       .success(function (data) {
                           $scope.device = data.body;
                           for (var i = 0 ; i < data.body.deviceListView.length ; i++) {
                               if (data.body.deviceListView[i].sn == $scope.deviceId) {
                                   $scope.device.deviceName = data.body.deviceListView[i].name;
                               }
                           }
                       }).error(function (data, status, headers, config) {
                           toastr.error($filter('translate')('toastrErrMsgGet'));
                       });
                    //@@@@@@ get Zone name
                    zoneProxy.getZoneInfo($scope.deviceId, $scope.zoneId)
                    .success(function (data) {
                        $scope.zone = data.body;

                    });

                    //************************************************
                   

                    
                 
                    $scope.goToPage = function (action, param1) {

                        fixLoadingOn(action, param1);
                        switch (action) {

                            case "project":
                                $state.go('site.preview.map', { siteId: $scope.device.projectID });
                                break;
                            case "site":
                                $state.go('site.preview.map', { siteId: $scope.device.siteID });
                                break;
                            case "device":
                                $state.go('device.XCI_device.online', {deviceId: $scope.deviceId});
                                break;

                        }
                    }

                    $scope.openZoneImgModal = function () {
                        $scope.openModal = true;
                    }
                    $("#splash-page").css("display", "none");
                }
                ]
            }
        }
    })
     .state('device.XCI_device.zones.adviser', {
         url: '/adviser',
         views: {
             '': {
                 template: '<div zones-categories></div>',
                 controller: ['$scope', '$stateParams', function ($scope, $stateParams) {
        
                     closeNavbar();
                     $("#splash-page").css("display", "none");
                 }
                 ]
             }
         }
     })
        
    

}]);

(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    ctrlHoldFactory.$inject = ['$log'];
    angular.module('module.XCI.Device')
        .directive('ctrlHold', ctrlHoldFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function ctrlHoldFactory($log) {

        return {
            restrict: 'EA',
            templateUrl: 'app/modules.devices/XCI.Device/online/ctrlHold.html',
            controller: ['$scope', '$locale', '$filter', 'translate', 'deviceProxy', function ($scope, $locale, $filter, translate, deviceProxy) {
                $scope.isDeviceOn= true,
                $scope.deviceStatus = {
                    isDeviceOn: true,
                    type: 'Permantly',
                    date: '',
                    time: ''
                };

                $scope.ladda = {
                    "hold": false
                };
               


                //************************************************************
                $scope.getDeviceStatus = function () {
                     deviceProxy.getDeviceHoldData($scope.deviceId)
                        .success(function (data, status, headers, config) {
                            $scope.deviceHoldData = data.body;
                            if (data.body.holdType == null) { // the device is active
                                $scope.isDeviceOn = true;
                                
                            } else {
                                if (data.body.holdType == 0) { // Hold until date
                                    $scope.deviceStatus.type = 'custom';
                                    $scope.isDeviceOn = false;
                                }
                                if (data.body.holdType == 1) { // parmanent Hold
                                    $scope.deviceStatus.type = 'Permantly';
                                    $scope.isDeviceOn = false;

                                }
                                $scope.setDate(translate.FixUnixGmtFromServer(data.body.holdUntil));
                                $scope.setTime(translate.FixUnixGmtFromServer(data.body.holdUntil));
                                
                            }
                            
                            
                        }).error(function (data, status, headers, config) {
                            toastr.error($filter('translate')('toastrErrMsgGet'));
                        });
                }
                $scope.getDeviceStatus();
                //************************************************************
                $scope.switchBotton = function (data) {
                    $scope.isDeviceOn = !data.isDeviceOn;
                    if (!$scope.isDeviceOn) { // device is off show date
                        $scope.deviceHoldData.holdType = 0;
                        $scope.deviceStatus.type = 'custom';
                        $scope.setDate(translate.FixUnixGmtFromServer($scope.deviceHoldData.holdUntil));
                        $scope.setTime(translate.FixUnixGmtFromServer($scope.deviceHoldData.holdUntil));
                    } else {
                        $scope.deviceHoldData.holdType = null;
                    }
                }
                //**************************************************************


             
              
                $scope.setDate = function (unix) {
                    $scope.deviceStatus.date = $filter('date')(unix, 'mediumDate');
                }
                $scope.setTime = function (unix) {
                    $scope.deviceStatus.time = $filter('date')(unix, 'shortTime');
                }
                $scope.clockType = translate.clockType($locale);
                
                $scope.saveHold = function () {
                    $scope.ladda.hold = true;
                 
                    $scope.deviceHoldData.holdUntil = translate.fullDateStringToUnixServer($scope.deviceStatus.date, $scope.deviceStatus.time);
                    if ($scope.deviceHoldData.holdType != null) {
                        $scope.deviceStatus.type == 'custom' ? $scope.deviceHoldData.holdType = 0 : $scope.deviceHoldData.holdType = 1;
                    }
                    deviceProxy.saveDeviceHoldData($scope.deviceId,$scope.deviceHoldData)
                       .success(function (data, status, headers, config) {
                           $scope.ladda.hold = false;
                           toastr.success('sucsess!');
                           $('#hold').modal('hide');
                       }).error(function (data, status, headers, config) {
                           toastr.error($filter('translate')('toastrErrMsgGet'));
                       });

                }

            }],
            link: function (scope, element, attrs) {
                var deviceId = attrs.device;
   
            }

        };//return
    }

    /*******************************************************************************************************************************************************************************/

})(angular);


(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.XCI.Device')
        .directive('onlineClock', onlineClockFactory);
    /*********************************************************************Online****************************************************************************************************/
    function onlineClockFactory() {



        return {
            restrict: 'EA',
            require: '?ngModel',
            scope:{

            },
            templateUrl: 'app/modules.devices/XCI.Device/online/clockTemplate.html',
            controller:['$scope', function ($scope) {
              
            }],

            link: function (scope, element, attrs, ngModel) {
                function PlaySound() {
                    var sound = document.getElementById("audio");
                    sound.play()
                }
                if (!ngModel) return; // do nothing if no ng-model
                ngModel.$render = function () {
                    var time = ngModel.$viewValue;
                    var zoneId = attrs.zone;
                    
                    $(element).timeTo(time, function () {

                        $(element).css({ "display": "none" });
                        
                        PlaySound();
                        scope.$emit('stopClock', zoneId);
                    });
                };
            }
        };
    }
    /*******************************************************************************************************************************************************************************/

})(angular);


//var stop = interval(function () {
//    var min = time / 60;
//    var sec = time % 60;
//    time--;
//    $scope.time = min + ":" + sec;

//}, 1000);





(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.XCI.Device')
        .directive('onlineDirective', onlineDirectiveFactory);
    /*********************************************************************Online****************************************************************************************************/
    function onlineDirectiveFactory() {
        var OnlineEvents = ['1000', '1011', '2301', '3001', '3002', '3003', '2000', '2001', '2002', '2003', '2004'];


        return {
            restrict: 'EA',

            templateUrl: 'app/modules.devices/XCI.Device/online/device.online.html',

            controller: ['$scope', 'deviceProxy', '$state', 'mainProvider', 'onlineProvider', '$filter', function ($scope, deviceProxy, $state, mainProvider, onlineProvider, $filter) {

                const MAX_DIFF_ZONES_UPDATE = 20;
                $scope.device = mainProvider.CurrentDevice.data;
                $scope.timer = false;
                $scope.alertCode = null;
                $scope.currentRuns = [];
                $scope.currentZone = { index: -1, URL: "", name: "" };
                var changeImage = 0;
                $scope.flipValue = 0;
                var deviceAlertsCodeArr = [];
                //****************************************************************
                function stringTimeToSeconds(strTime) {
                    if (!strTime) {
                        return 0;
                    }
                    return parseInt(strTime.Hours) * 3600 + parseInt(strTime.Minutes) * 60 + parseInt(strTime.Seconds);
                }
                //****************************************************************
                $scope.getZone = function (zoneId, zoneName) {
                    $scope.currentZoneManual = { zoneId: zoneId, zoneName: zoneName };
                }
                //**************************************************************
                $scope.startManualOperation = function (time) {

                    //send to server
                    deviceProxy.manualZoneOperationOnline($scope.deviceId, $scope.currentZoneManual.zoneId, stringTimeToSeconds(time))
                        .success(function (data, status, headers, config) {

                        }).error(function (data, status, headers, config) {

                        });

                    //*****************
                    $('#setZoneTime').modal('hide');
                }
                //***************************************************************
                function buildStringFromArray(arr, filterBy) {
                    var str = "";
                    for (var i = 0; i < arr.length; i++) {
                        var val = $filter('translate')(filterBy + arr[i])
                        if (str == "") {
                            str = val + ", ";
                        } else {
                            i == arr.length - 1 ? str = str + val : str = str + val + ", ";
                        }

                    }
                    return str;
                }
                //*************************************************************
                $scope.resetAlrts = function () {
                    //service missing
                }
                //*************************************************************
                $scope.changeCurrentRunningZone = function (index) {
                    var temp = $scope.currentRuns[0];
                    $scope.currentRuns[0] = $scope.currentRuns[index];
                    $scope.currentRuns[index] = temp;
                }
                //*************************************************************
                function onlineCBfuncOnlinePage(data) {
                    var original = String(data.code);
                    var prefix = original.substring(0, 2);
                    switch (prefix) {


                        case "10": // connection , pause , sync

                            if (original == "1000") {   // connection , pause

                                if (data.connection) {   // active
                                    $("div[onlinetarget='deviceStatus']").addClass('active');
                                }
                                if (!data.connection) { // offline
                                    $("div[onlinetarget='deviceStatus']").removeClass('active');
                                }
                                if (data.connection && data.status == 1) {  //pause
                                    $("div[onlinetarget='pause']").addClass('active');
                                }
                                if (data.connection && data.status == 0) {  //pause
                                    $("div[onlinetarget='pause']").removeClass('active');
                                }
                            }
                            if (original == "1011") { //sync
                                if (data.isSync) {
                                    $("div[onlinetarget='sync']").addClass('active');
                                }
                                if (!data.isSync) {
                                    $("div[onlinetarget='sync']").removeClass('active');
                                }
                            }
                            break;



                        case "23": // Digital Input state (single input)

                            if (original == "2301") { // rain sennsor
                                if (data.state) {
                                    $("div[onlinetarget='rain']").addClass('active');
                                }
                                if (!data.state) {
                                    $("div[onlinetarget='rain']").removeClass('active');
                                }
                            }
                            break;

                        case "30":  //Water Meter
                            if (original == "3001") {
                                $scope.maValue = data.value;
                              //  $scope.$apply();
                            }
                            if (original == "3002") {
                                $scope.gpmValue = data.value;
                              //  $scope.$apply();
                            }
                            if (original == "3003") {
                                $scope.flipValue = data.value;
                           //     $scope.$apply();
                            }
                            break;

                        case "20":  //Alerts
                            if (data.state) {
                                $("div[onlinetarget='alert']").addClass('active');
                                if (deviceAlertsCodeArr.indexOf(original) == -1) {
                                    deviceAlertsCodeArr.push(original);
                                }
                            }
                            if (!data.state) {
                                var index = deviceAlertsCodeArr.indexOf(original);
                                deviceAlertsCodeArr.splice(index, 1);
                                if (deviceAlertsCodeArr.length == 0) {
                                    $("div[onlinetarget='alert']").removeClass('active');
                                }
                            }

                            $scope.alertCoded = buildStringFromArray(deviceAlertsCodeArr, "MF_ALERTS_ALERTS_CODE_");
                         //   $scope.$apply();
                            break;
                        case "40":  //Zones
                            var zoneNumber = parseInt(original.substring(2));
                            calcZoneTimeLeft($scope.zonesList[zoneNumber], data);

                          //  $scope.$apply();
                            break;


                    }
                }
                //****************************************************************
                function parseSecondsToStringDate(sec) {
                    var seconds = Math.floor(sec % 60).toString();
                    var minutes = Math.floor((sec / 60) % 60).toString();
                    var hours = Math.floor((sec / (60 * 60)) % 24).toString();
                    if (seconds.length == 1) {
                        seconds = '0' + seconds;
                    }
                    if (minutes.length == 1) {
                        minutes = '0' + minutes;
                    }
                    if (hours.length == 1) {
                        hours = '0' + hours;
                    }
                    return hours + ':' + minutes + ':' + seconds
                }
                //***************************************************************
                function calcZoneTimeLeft(zone, event) {
                    var timeLeft_Sec = event.timeUnit == 'minute' ? event.timeLeft * 60 : event.timeLeft;

                    var serverUTC = new Date().getTime() + onlineProvider.getDiffUTC();  // server current time
                    var deffBetweenLastUbdateToEventTime = (serverUTC - event.lastUpdate);
                    var newTimeLeft = timeLeft_Sec - (deffBetweenLastUbdateToEventTime / 1000);  //ex' last update 8:00:00 time left 7 min  ; now 08:00:30 ---> deffBetweenLastUbdateToEventTime = 30   ---> newTimeLeft = 6:30 minutes
                    if (newTimeLeft < 2) {
                        zone.timeLeftStr = null;
                        var ind = $scope.currentRuns.indexOf(zone.zoneNumber - 1);
                        $scope.currentRuns.splice(ind, 1);
                        return;
                    }

                    //calc the diff between the two:
                    //      a. local time left (timeLeft_Sec changed by timer)
                    //      b. server time left (newTimeLeft, calculted using the onlineProvider.getDiffUTC())
                    var diffTimeLeft = zone.timeLeftStr ? Math.abs(newTimeLeft - zone.timeLeft_Sec) : MAX_DIFF_ZONES_UPDATE + 1;

                    if (diffTimeLeft > MAX_DIFF_ZONES_UPDATE) {
                        zone.timeLeft_Sec = newTimeLeft;
                        zone.timeLeftStr = parseSecondsToStringDate(newTimeLeft);
                    }
                }
                //***************************************************************
                function intervalFunction(zonesList, currentZone, currentRuns) {

                    changeImage++;
                    for (var i = 0; i < zonesList.length; i++) {
                        if (zonesList[i].timeLeftStr) {
                            if (zonesList[i].timeLeft_Sec > 1) {
                                if (currentRuns.indexOf(i) == -1) { // new zone running push index to array
                                    currentRuns.push(i);
                                }
                                zonesList[i].timeLeft_Sec--;
                                zonesList[i].timeLeftStr = parseSecondsToStringDate(zonesList[i].timeLeft_Sec);
                            } else {
                                zonesList[i].timeLeftStr = null;
                                var removeIndex = currentRuns.indexOf(i);
                                currentRuns.splice(removeIndex, 1);
                            }

                        }
                    }
                    if (changeImage % 3 == 0) {
                        if (currentZone.index >= zonesList.length - 1) {
                            currentZone.index = -1;
                        }
                        currentZone.index++;
                        currentZone.URL = zonesList[currentZone.index].imageURI;
                        currentZone.name = zonesList[currentZone.index].name;

                    }
                }
                //***************************************************************
                function addToOnlineArrayZonesEvents(zones) {
                    for (var i = 0; i < zones.length; i++) {
                        OnlineEvents.push(4000 + zones[i].zoneNumber-1);
                    }
                }
                //**************************************************************
                $scope.getZonesActivateList = function (deviceId) {

                    deviceProxy.getZonesActivateList(deviceId)
                        .success(function (data, status, headers, config) {
                            $scope.zonesList = data.body;
                            addToOnlineArrayZonesEvents(data.body);
                            onlineProvider.registerDevice(OnlineEvents, deviceId, 'DeviceOnline', onlineCBfuncOnlinePage);
                            fixLoadingOff();
                        }).error(function (data, status, headers, config) {

                        });
                }
                //***************************************************************
                $scope.goToZone = function (zoneId) {
                    $state.go('device.XCI_device.zones.adviser', { zoneId: zoneId });
                }
                //*******************************************************
                $scope.maObj = {
                    "data": { "Label": "mA", "Value": 0 },
                    "options": { "height": 170, "redFrom": 100, "redTo": 120, "yellowFrom": 75, "yellowTo": 100, "majorTicks": [0, 20, 40, 60, 80, 100, 120], "minorTicks": 7, "max": 120, "min": 0 }
                }
                $scope.gpmObj = {
                    "data": { "Label": "GPM", "Value": 0 },
                    "options": { "height": 170, "redFrom": 90, "redTo": 100, "yellowFrom": 75, "yellowTo": 90, "majorTicks": [0, 20, 40, 60, 80, 100], "minorTicks": 6, "max": 100, "min": 0 }
                }

                //*****************************************************************************
                $scope.goToZone = function (zoneId) {
                    fixLoadingOn("ZoneAdviser");
                    $state.go('device.XCI_device.zones.adviser', { zoneId: zoneId });
                }
                //*****************************************************************************************
                function callIntervalFunc() {
                    intervalFunction($scope.zonesList, $scope.currentZone, $scope.currentRuns);
                }
                //********************************************************
                onlineProvider.registerIntervalCallback(callIntervalFunc);
            }],
            link: function (scope, element, attrs) {

                scope.getZonesActivateList(scope.deviceId);

            }




        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);









(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.device')
        .directive('gmapOnline', ['onlineProvider', '$state','siteProxy', gmapOnlineFactory]);

    /************************************************************************************************************************************************************************/
    function gmapOnlineFactory(onlineProvider, $state, siteProxy) {

        var marker = { sn: $state.params.deviceId, marker: '' };
        var OnlineEvents = ['1000'];
        var map;
        return {
            restrict: 'A',
            transclude: true,
            scope: { location: '=' },
            template: '<div id="map-canvas" style="height: 250px"></div> ',
            replace: true,
            link: function (scope, element, attrs) {




                //**************************************Functions**************************

                function onlineDeviceFuncMap(data) {
                    switch (String(data.code)) {
                        case "1000":

                            if (marker.sn == data.sn) {
                                if (!data.connection) {
                                    marker.iconUrl = '../../../../../content/img/grey-dot.png';
                                    marker.marker.setIcon({ url: '/Content/img/grey-dot.png' });
                                }
                                if (data.connection) {
                                    marker.iconUrl = '../../../../../content/img/green-dot.png';
                                    marker.marker.setIcon({ url: '../../../../../Files/content/img/green-dot.png' });
                                }
                                if (data.connection && data.isFailure) {
                                    marker.iconUrl = '../../../../../content/img/green-dot-Alert.png';
                                    marker.marker.setIcon({ url: '../../../../../Files/content/img/green-dot-Alert.png' });
                                }
                                if (data.connection && data.isIrrigating) {
                                    marker.iconUrl = '../../../../../content/img/green-dot-Irrigate.png';
                                    marker.marker.setIcon({ url: '../../../../../Files/content/img/green-dot-Irrigate.png' });
                                }
                                if (data.connection && data.isFertilizing) {

                                    marker.marker.setIcon({ url: '../../../../../Files/content/img/green-dot-Fertilizing.png' });
                                }
                            }
                            break;
                    }
                }


                createMap(scope.location);
                onlineProvider.registerDevice(OnlineEvents, marker.sn, 'deviceMap', onlineDeviceFuncMap);
                //**************************************************************************
                function navigate(location) {
                    // If it's an iPhone..
                    if ((navigator.platform.indexOf("iPhone") != -1)
                        || (navigator.platform.indexOf("iPod") != -1)
                        || (navigator.platform.indexOf("iPad") != -1)) {
                        return "http://maps://maps.google.com/maps?daddr=" + location.lat() + "," + location.lng() + "&amp;ll=";
                    }
                    else {
                        return "http://maps.google.com/maps?daddr=" + location.lat() + "," + location.lng() + "&amp;ll=";
                    }
                };
                //**************************************createMap(Inner)*******************
                function createMap(data) {
                    var geocoder = geocoder = new google.maps.Geocoder();
                    var mapOptions = {
                        center: new google.maps.LatLng(data.latitude, data.longitude),
                        zoom: 8,
                        mapTypeId: google.maps.MapTypeId.ROADMAP
                    };

                    var map = new google.maps.Map(element[0], mapOptions);

                    var myLatlng = new google.maps.LatLng(data.latitude, data.longitude);
                    marker.marker = new google.maps.Marker({
                        position: myLatlng,
                        map: map,
                        draggable: true,
                        animation: google.maps.Animation.DROP,
                        icon: 'https://maps.google.com/mapfiles/ms/icons/green-dot.png'
                    });

                    google.maps.event.addListener(marker.marker, "dragend", function (e) {
                        var lat, lng, address;
                        geocoder.geocode({ 'latLng': marker.marker.getPosition() }, function (results, status) {
                            if (status == google.maps.GeocoderStatus.OK) {
                                // save new location
                                //SaveSiteDeviceChangeLocation(devices, marker.sn, marker.marker.getPosition().lat(), marker.marker.getPosition().lng());
                                siteProxy.saveDeviceLocation(marker.sn, marker.marker.getPosition().lat(), marker.marker.getPosition().lng())
                                   .success(function (data) {
                                   
                                   });
                                
                            }
                        });

                    });
                    //***************************************************************************
                    google.maps.event.addListener(marker.marker, "click", function (e) {
                        var navigateUrl = navigate(marker.marker.position);
                        var contentString = 
                       '<i class="fa fa-map-marker marginRight7"></i><a href=' + navigateUrl + '>Navigate to device</a>'
                        var infowindow = new google.maps.InfoWindow({
                            content: contentString,
                            maxWidth: 270
                        });
                        infowindow.open(map, marker.marker);

                    });



                }


                //***********************************************************************
            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);

(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.XCI.Device')
        .directive('setOnlineTime', setOnlineTimeFactory);
    /********************************************************************************************************************************************************************/
    function setOnlineTimeFactory() {
        return {
            restrict: 'EA',
            require: '?ngModel',
            templateUrl: 'app/modules.devices/XCI.Device/online/setOnlineTime.html',
            controller:['$scope','$rootScope','zoneProxy', function ($scope, $rootScope, zoneProxy) {
                //************************************Attribute**********************************
                $scope.time = {
                    "Hours": 10,
                    "Minutes":15
                }
                $scope.timeformValidation = false;
                //************************************addHours**********************************
                $scope.addHours=function(){
                    if ($scope.time.Hours<99) {
                        $scope.time.Hours++;
                    }
                }
                //************************************subHours**********************************
                $scope.subHours = function () {
                    if ($scope.time.Hours > 0) {
                        $scope.time.Hours--;
                    }
                }
                //************************************addMinutes**********************************
                $scope.addMinutes = function () {
                    if ($scope.time.Minutes <59) {
                        $scope.time.Minutes++;
                    } else {
                        $scope.time.Minutes = 0;
                        $scope.addHours();
                    }
                }
                //************************************subMinutes**********************************
                $scope.subMinutes = function () {
                    if ($scope.time.Minutes > 0) {
                        $scope.time.Minutes--;
                    } else {
                        $scope.time.Minutes = 0;
                        $scope.time.Minutes = 59;
                        $scope.subHours();
                    }
                }
                //************************************start**********************************
                $scope.start = function (timeform ,func) {
                    if (timeform) {
                        $scope.timeformValidation = false;
                        var resetTime = $scope.time.Hours * 3600 + $scope.time.Minutes * 60;
                        func();
                         //zoneProxy.manualStartIrrigation($scope.deviceId, $scope.zoneId, resetTime)
                         //.success(function (data) {
                         //    toastr.success('Manual start irrigation', 'success!');
                        //});
                        //$rootScope.$broadcast('stoptime');
                    var obj = {
                        OnlineEventNumber: 1,  // manualStartIrrigation
                        time: resetTime,
                        deviceId: $scope.deviceId,
                        zoneId: $scope.zoneId
                    }
                        //@@@@@
                    $rootScope.$broadcast('onlineEvent', { obj: obj });
                    } else {
                        $scope.timeformValidation = true;
                    }
                }

            }],
            //************************************link**********************************
            link: function (scope, element, attrs, ngModel) {
                if (!ngModel) return; // do nothing if no ng-model
                ngModel.$render = function () {
                    scope.deviceId = attrs.device;
                    scope.zoneId = ngModel.$viewValue;
                    
                };

            }
        };//return
    }
    //*******************************************************************************************************************************************************************************/
})(angular);


(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.XCI.Device')
        .directive('daySetting', daySettingFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function daySettingFactory() {
        return {
            restrict: 'EA',
            templateUrl: 'app/modules.devices/XCI.Device/view/daySetting.html',
            scope: {
                comm: '='
            },
            controller: ['$scope', '$locale', 'translate', '$filter', 'deviceProxy', 'siteProxy', '$stateParams', 'user', 'mainRouter', function ($scope, $locale, translate, $filter, deviceProxy, siteProxy, $stateParams, user, mainRouter) {
                //*************************************Attributs*************************************
                $scope.locale = $locale;
                $scope.clockType = translate.clockType($locale);
                $scope.ladda = {
                    saveDaySettings:false
                }

                if ($stateParams.deviceId) {
                    $scope.useDevice = true;
                    $scope.deviceId = $stateParams.deviceId;
                } else {
                    $scope.useDevice = false;
                    $scope.siteId = $stateParams.siteId;
                }
                
                $scope.privilige = user.getSharingData().sharingData.roleModify;
               
                $scope.dami = ['', ''];
                //***********************************************************
                $scope.comm.SetCallbackDown(function (data) {
                    $scope.daySetting = data.body;
                    $scope.daySetting = $scope.addTimeStrProperty($scope.daySetting);
                    $scope.start = true;

                });
                //***********************************************************
                $scope.saveDaySetting = function () {
                   
                    $scope.ladda.saveDaySetting = true;
                    //**************************************************
                    for (var i = 1; i < $scope.daySetting.listDays.length; i++) {
                        for (var j = 0; j < $scope.daySetting.listDays[i].times.length; j++) {
                            $scope.daySetting.listDays[i].times[j].time = $scope.daySetting.listDays[0].times[j].time;
                            
                        }

                    }

                    //***************************************************


                    if ($scope.useDevice) {
                        deviceProxy.saveDaySetting($scope.deviceId, $scope.daySetting.listDays)
                          .success(function (data) {
                              $scope.comm.CallbackUp();
                              mainRouter.callkey("refreshTable", {});
                              $scope.ladda.saveDaySetting = false;
                          });
                    } else {
                        siteProxy.saveOneSesson($scope.siteId, $scope.daySetting.sessionID, $scope.daySetting.listDays)
                                     .success(function (data) {

                                         $scope.comm.CallbackUp();
                                         $scope.ladda.saveDaySetting = false;
                                         toastr.success('changes saves', 'success!');
                                     });
                    }
                    
                 
                }
                //**********************************************************
                $scope.addTimeStrProperty = function (daySetting) {
                    for (var i = 0; i < daySetting.listDays.length; i++) {
                        for (var j = 0; j < daySetting.listDays[i].times.length; j++) {
                            var time = $filter('date')(translate.convertUnixToTime(daySetting.listDays[i].times[j].time), 'shortTime');
                            daySetting.listDays[i].times[j]['timeStr'] = time;
                        }
                        
                    }
                    
                    return daySetting;
                }
                //***********************************************************
                $scope.saveLastDateObject = function (obj) {
                    $scope.lastObj = jQuery.extend(true, {}, obj);
                }
                //**********************************************************
                $scope.dateValidateAndPharse = function (obj, index) {
                    if (dateValidate(obj, index, $scope.daySetting.listDays[0].times)) {
                           
                        } else {
                            alert('Start Date Error');
                            for (var a in $scope.lastObj) {
                                obj[a] = $scope.lastObj[a];
                            }
                        }
                }
                //**************************************************************
                function dateValidate(obj, index, list) {
                    if (index > 0) {
                        obj.time = translate.stringToUnix(obj.timeStr);
                        while (index > 0) {
                            if (obj.time < list[index - 1].time) {
                                return false;
                            }
                            index--;
                        }
                    } else {
                        return true;
                    }
                    return true;
                }
                //*************************************************************************************
                //function pharseDate(obj) {
                //        obj.time = obj.timeStr;
                //        obj.timeStr = translate.convertUnixToTime(obj.time);
                //}

            }],
            link: function (scope, element, attrs) {
                //scope.attr = attrs.param;    //site or device

            }




        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);








(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.XCI.Device')
        .directive('deviceView', deviceViewFactory);
    /*********************************************************************************************************************************************************/
    function deviceViewFactory() {
        return {
            restrict: 'EA',
            require: '?ngModel',
            templateUrl: 'app/modules.devices/XCI.Device/view/device.view.html',
            controller: ['$scope', 'deviceProxy', 'zoneProxy', '$locale', 'translate', '$filter', '$state', 'directiveComm', 'mainRouter','user', function ($scope, deviceProxy, zoneProxy, $locale, translate, $filter, $state, directiveComm, mainRouter,user) {
                //********************************************Attributes*****************************************************
                $scope.privilige = user.getSharingData().sharingData.roleModify;
                $scope.ladda = {
                    "scheduleView": false,
                    "settings": false,
                    "rainSensorSettings": false,
                    "irrigatingSettings": false,
                    "flowSensorSettings": false,
                    "SaveAlerts": false,
                    "SaveAlertsModal": false,
                    "deleteCtrl": false
                };
                $scope.validation = {
                    "flowValid": false,
                    "rainValid": false,
                    "alertsValid": false,
                    "irrigationValid":false
                }
                $scope.scheduleConnector = directiveComm.CreateConnector();
                $scope.daySettingConnector = directiveComm.CreateConnector();
                $scope.scheduleConnector.SetCallbackUp(function () {
                });
                $scope.locale = $locale;
                $scope.translate = translate;
                $scope.type = translate.clockType($locale);
                //**************************************getViewPage(Outer)*****************
                $scope.getViewPage = function (deviceId) {
                    deviceProxy.getViewPage(deviceId)
                       .success(function (data) {
                           data = data.body;
                           $scope.allObject = data.deviceSettingsView;
                           $scope.settings = data.deviceSettingsView.deviceSettings;
                           $scope.displaySettings = data.deviceSettingsView.displaySettings;
                           $scope.irrigatingSettings = data.deviceSettingsView.irrigatingSettings;
                           $scope.rainSensorSettings = data.deviceSettingsView.rainSensorSettings;
                           $scope.flowSensorSettings = data.deviceSettingsView.flowSensorSettings;
                           $scope.deviceAlertsSettings = data.deviceSettingsView.alertThresholdSettings;
                           $scope.irrigationSchedule = data.deviceSettingsView.irrigationSchedule;
                           $scope.zonesListLength = data.deviceSettingsView.irrigationSchedule.zones.length;
                           $scope.settings.holdUntilStr = $filter('date')($scope.settings.holdUntil, 'medium', 'UTC');
                            
                         
                           fixLoadingOff();
                           
                       });
                }
                //*************************************************************************************************
                $scope.getDaySetting = function () {
                    deviceProxy.getDaySetting($scope.deviceId)
                       .success(function (data) {
                           $scope.daySetting = data;
                           $scope.daySettingConnector.CallbackDown(data);
                           $scope.showDirective = true;
                       });
                }
          
                ////*********************************************changeDeviceName(Outer)**************************************************************
                $scope.changeDeviceName = function (id, newName) {
                    deviceProxy.changeDeviceName(id, newName)
                       .success(function (data) {
                           toastr.success('changes saves', 'success!');
                       });
                }

                //********************************************************************************************
                $scope.SaveDeviceAlertsSettings = function (alertForm) {
                    if (alertForm) {
                        $scope.ladda.SaveAlerts = true;     
                        deviceProxy.saveAlertSetting($scope.deviceId, $scope.deviceAlertsSettings)
                            .success(function (data, status, headers, config) {
                                toastr.success('Changes Saves', 'Success!');
                                $scope.ladda.SaveAlerts = false;
                            })
                            .error(function (data, status, headers, config) {
                                toastr.error('Changes not Saves', 'Error!');
                                $scope.ladda.SaveAlerts = false;
                            });
                    } else {
                        $scope.validation.alertsValid = true;
                    }
                }
                //*******************************************************************************
                $scope.openAddAlerts = function (param) {

                    deviceProxy.openAddAlerts(param)
                    .success(function (data) {
                
                        $scope.alerts = data.body;
                    });
                }
                //*******************************************************************************
                $scope.saveAlertsModal = function () {
                    $scope.ladda.SaveAlertsModal = true;
                    deviceProxy.CtrlAlertsSavings($scope.deviceId, $scope.alerts)
                        .success(function (data, status, headers, config) {
                            toastr.success('Changes Saves', 'Success!');
                            $scope.ladda.SaveAlertsModal = false;
                         
                        })
                        .error(function (data, status, headers, config) {
                            toastr.error($filter('translate')('toastrErrMsgGet'));
                        });
                }
               
                ////*******************************************switchDeviceAlerts(Outer)****************************************************************
                $scope.switchDeviceAlerts = function (isAlert) {
                    if ($scope.privilige) {
                        $scope.deviceAlertsSettings.isAlertsEnabled = !isAlert;
                    }
                };
                ////*******************************************switchUseWeather(Outer)****************************************************************
                $scope.switchUseWeather = function (bool) {
                    if ($scope.privilige) {
                        $scope.settings.userWeatherSavingAlgorithm = !bool;
                    }
                    

                };
                ////*********************************************changeDay(Outer)**************************************************************
                $scope.changeDay = function (dayNum, dayString) {
                    $scope.currentDayNum = dayNum;
                    $scope.currentDayString = dayString;

                }
                ////********************************************saveSchedual(Outer)***************************************************************         
                $scope.saveSchedual = function () {
                    $scope.ladda.scheduleView = true;

                    deviceProxy.SaveSchedule($scope.deviceId, $scope.irrigationSchedule)
                       .success(function (data) {
                           toastr.success('changes saves', 'success!');
                           $scope.ladda.scheduleView = false;
                       });
                   
                    
                }
                ////*********************************************SaveSettings(Outer)**************************************************************
                $scope.SaveSettings = function () {
                    $scope.ladda.settings = true;
                    var obj = {
                        'deviceSettings': $scope.settings,
                        'displaySettings': $scope.displaySettings,
                    }
                    deviceProxy.SaveSettings($scope.deviceId, obj)
                        .success(function (data) {
                            toastr.success('changes saves', 'success!');
                            $scope.ladda.settings = false;
                        });
                }
                ////*******************************************switchDeviceAlerts(Outer)****************************************************************
                $scope.switchUseSeason = function (isSeason) {
                    if ($scope.privilige) {
                        $scope.settings.useSiteSessionSettings = !isSeason;
                    }
                };
                ////*********************************************SaveIrrigatingSettings(Outer)**************************************************************
                $scope.SaveIrrigatingSettings = function (irrigationForm) {
                    if (irrigationForm) {
                        $scope.ladda.irrigatingSettings = true;
                        var obj = {
                            'irrigatingSettings': $scope.irrigatingSettings
                        }
                        deviceProxy.SaveSettings($scope.deviceId, obj)
                            .success(function (data) {
                                toastr.success('changes saves', 'success!');
                                $scope.ladda.irrigatingSettings = false;
                            });
                    } else {
                        $scope.validation.irrigationValid = true;
                    }
                }
                ////************************************************SaveRainSensor(Outer)***********************************************************
                $scope.SaveRainSensor = function (RainForm) {
                    if (RainForm) {
                        $scope.ladda.rainSensorSettings = true;
                        var obj = {
                            'rainSensorSettings': $scope.rainSensorSettings
                        }
                        deviceProxy.SaveSettings($scope.deviceId, obj)
                            .success(function (data) {
                                toastr.success('changes saves', 'success!');
                                $scope.ladda.rainSensorSettings = false;
                            });
                    } else {
                        $scope.validation.rainValid = true;
                    }
                }
                ////************************************************SaveflowSensorSettings(Outer)***********************************************************
                $scope.SaveflowSensorSettings = function (FlowForm) {
                    if (FlowForm){
                    $scope.ladda.flowSensorSettings = true;
                    var obj = {
                        'flowSensorSettings': $scope.flowSensorSettings
                    }
                    deviceProxy.SaveSettings($scope.deviceId, obj)
                        .success(function (data) {
                            toastr.success('changes saves', 'success!');
                            $scope.ladda.flowSensorSettings = false;
                        });
                    } else {
                        $scope.validation.flowValid = true;
                    }
                }
                ////************************************************getZone(Outer)***********************************************************
                $scope.getZone = function (zoneId, zoneName) {
                    //zone irrigation sceduale
                    $scope.currentZoneName = zoneName;
                    $scope.zoneId = zoneId;
                    zoneProxy.getZoneSchedule($scope.deviceId, zoneId)
                       .success(function (data) {
                           $scope.zoneScheduleView = data.body.scheduleView;
                       });
                }
                //************************************************saveIrrigationByzoneSchedule(Outer)****************************
                $scope.saveIrrigationByzoneSchedule = function () {
                    //zone irrigation sceduale
                    zoneProxy.saveTableIrrigationByZone($scope.deviceId, $scope.zoneId, $scope.zoneScheduleView)
                            .success(function (data) {
                                toastr.success('changes saves', 'success!');
                            });
                }
                //*************************************************NextZone(Outer)***************************
                $scope.NextZone = function (zoneNumber) {
                    if (zoneNumber < $scope.zonesListLength) {
                        zoneNumber++;
                        zoneProxy.getZoneSchedule($scope.deviceId, zoneNumber)
                           .success(function (data) {
                               $scope.zoneScheduleView = data.body.scheduleView;
                               //run irrigation by zone directive , data.body.scheduleView must include zone name 
                               //$scope.currentZoneName = zoneName;
                               //$scope.zoneId = zoneId;

                           });
                    }
                }
                //***************************************************PrevZone(Outer)*************************
                $scope.PrevZone = function (zoneNumber) {
                    if (zoneNumber > 1) {
                        zoneNumber--;
                        zoneProxy.getZoneSchedule($scope.deviceId, zoneNumber)
                           .success(function (data) {
                               $scope.zoneScheduleView = data.body.scheduleView;
                               //run irrigation by zone directive
                           });
                    }
                }
                //************************************************deleteCtrl(Outer)****************************
                $scope.deleteCtrl = function (ControllerId) {
                    $scope.ladda.deleteCtrl = true;
                    deviceProxy.deleteCtrl(ControllerId)
                    .success(function (data, status, headers, config) {
                        toastr.success('controller deleted', 'Success!');
                        $scope.ladda.deleteCtrl = false;
                        $state.go('site.preview.list', { projectId: $scope.projectId, siteId: $scope.siteId });
                    })
                    .error(function (data, status, headers, config) {
                        toastr.error('controller not deleted', 'Error!');
                    });
                }
                //****************************************************************************
                mainRouter.register("saveScedual", function (data) {
                    $scope.irrigationSchedule = data;
                });
                //****************************************************************
                $scope.daySettingConnector.SetCallbackUp(function (data) {

                    $('#daySetting').modal('hide');

                });
               //*************************************************Link***************************
            }],
            link: function (scope, element, attrs, ngModel) {
                if (!ngModel) return; // do nothing if no ng-model
                ngModel.$render = function () {
                    scope.deviceId = ngModel.$viewValue;
                    scope.getViewPage(scope.deviceId);
                };
            }
        };
    }

})(angular);




(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module("module.XCI.Device")
        .directive('irrigationByZone', irrigationByZoneFactory);
    /********************************************************************************************************************************************************************/
    function irrigationByZoneFactory() {

        return {
            restrict: 'EA',
            require: '?ngModel',
            scope: {
                scheduleview: '=',
                comm: '='
            },
            templateUrl: 'app/modules.devices/XCI.Device/view/irrigationByZone.html',
            controller:['$scope','$locale','translate', function ($scope,$locale,translate) {
                //********************************Attributes************************************
                $scope.locale = $locale;
                $scope.translate = translate;
               
                //**************************************************************************
                $scope.pharseTime = function (scheduleview) {
                    for (var i = 0; i < scheduleview.rows.length; i++) {
                        for (var j = 0; j < scheduleview.rows[i].days.length; j++) {
                            scheduleview.rows[i].days[j].durationStr = scheduleview.rows[i].days[j].duration / 60;
                        }
                    }
                    $scope.startPage = true;
                }
                
                //***************************************************************************
                $scope.bodyValChange = function (tb) {
                    tb.duration = parseFloat(tb.durationStr) * 60;
                }
                //********************************sumRow************************************
                $scope.sumRow = function (index) {
                    $scope.sumAll = 0;
                   $scope.scheduleview.rows[index].sum = 0;
                    for (var i = 0; i <$scope.scheduleview.rows[index].days.length; i++) {
                        
                        $scope.scheduleview.rows[index].sum = $scope.scheduleview.rows[index].sum + parseInt($scope.scheduleview.rows[index].days[i].durationStr || 0);
                    }
                    for (var i = 0; i <$scope.scheduleview.rows[index].days.length; i++) {
                        if ($scope.scheduleview.rows[i]) {
                            $scope.sumAll = $scope.sumAll +$scope.scheduleview.rows[i].sum;
                        }
                        
                    }
                    return $scope.scheduleview.rows[index].sum;
                }
            }],
            link: function (scope, element, attrs, ngModel) {
                scope.type = attrs.page;
                if (!ngModel) return;
                ngModel.$render = function () {
                   
                    scope.pharseTime(scope.scheduleview);
                };
            }
        };//return
    }
})(angular);


(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module("module.XCI.Device")
        .directive('zonesIrrigationByDay', zonesIrrigationByDayFactory);
    /********************************************************************************************************************************************************************/
    function zonesIrrigationByDayFactory() {
        return {
            restrict: 'EA',
            require: '?ngModel',
            scope: {
                scheduleview: '='
            },
            templateUrl: 'app/modules.devices/XCI.Device/view/byDay.html',
            controller: ['$scope', '$locale', 'translate', '$state', function ($scope, $locale, translate, $state) {
                const maxStarts = 4;
                $scope.locale = $locale;
                $scope.translate = translate;
                $scope.v = $scope.scheduleview;
                //*********************************************************************************************************
                $scope.type = translate.clockType($locale);
                //**************************************************stringToUnix*******************************************
                $scope.stringToUnix = function (index, str) {
                    var time = translate.stringToUnix(str);
                    $scope.scheduleview.startTimes[index].time = time;
                }
                //*********************************************************************
                $scope.isAllowedTimeChanged = function (tb,index) {
                    $scope.newClickedItem = tb;
                    $scope.newClickedIndex = index;
                    var time = translate.stringToUnix(tb.timeStr);
                    if (!isIrrigationTimeAllowed(time)) {
                   
                        $('#timeNotAllowed').modal({
                            show: 'true'
                        })
                 
                    } else {
                        $scope.scheduleview.startTimes[index].time = time;
                     
                    }
                }
                //******************************************************************
                $scope.allowAnyWay = function () {

                     var time = translate.stringToUnix($scope.newClickedItem.timeStr);
                     $scope.scheduleview.startTimes[$scope.newClickedIndex].timeStr = $scope.newClickedItem.timeStr;
                     $scope.scheduleview.startTimes[$scope.newClickedIndex].time = time;
                    $('#timeNotAllowed').modal('hide');
                }
                //*********************************************************************
                $scope.discardChanges = function () {

                    var time = translate.stringToUnix($scope.lastClickedItem.timeStr);
                    $scope.scheduleview.startTimes[$scope.lastClickedIndex].timeStr = $scope.lastClickedItem.timeStr;
                    $scope.scheduleview.startTimes[$scope.lastClickedIndex].time = time;
                    $('#timeNotAllowed').modal('hide');
                }
                //*************************************************************************
                $scope.bodyValChange = function (tb) {
                    tb.duration = parseFloat(tb.durationStr) * 60;
                }
                //*************************************************addTimeCol**********************************************
                $scope.addTimeCol = function () {
                    if ($scope.scheduleview.startTimes.length < maxStarts) {
                        var obj = {};
                        if ($scope.type == "AMPM") {
                            obj.timeStr = '09:00AM';
                        }
                        else {
                            obj.timeStr = '09:00';
                        }
                        obj.time = translate.stringToUnix("09:00AM")

                        $scope.scheduleview.startTimes.push(obj)
                        for (var i = 0; i < $scope.scheduleview.zones.length; i++) {
                            var obj = {};
                            obj.duration = 0,
                            obj.quantity = 0;
                            obj.durationStr = '';
                            $scope.scheduleview.zones[i].starts.push(obj);

                        }
                    }
              

                }
                //**************************************************delTimeCol*********************************************
                $scope.delTimeCol = function (Index) {
                    if ($scope.scheduleview.startTimes.length > 1) {
                        $scope.scheduleview.startTimes.splice(Index, 1);
                        for (var i = 0; i < $scope.scheduleview.zones.length; i++) {

                            $scope.scheduleview.zones[i].starts.splice(Index, 1);

                        }
                    }
                    
                  
                  
                

                }
                //*****************************************************************************************************
                $scope.goToZone = function (zoneId) {
                    fixLoadingOn("ZoneOddAdviser");
                    $state.go('device.XCI_device.zones.adviser', { zoneId: zoneId });
                }
                //*********************************************************************************************************
                $scope.saveLastClickedItem = function (lastClickedItem, index) {
                    if ($scope.scheduleview.scheduleType == 'Weekly') {
                        $scope.lastClickedIndex = index;
                        $scope.lastClickedItem = jQuery.extend(true, {}, lastClickedItem);
                    }
                }
                //***********************************************************************************************

                var isIrrigationTimeAllowed = function (time) {
                    if ($scope.scheduleview.scheduleType == 'Weekly') {
                        var times = $scope.scheduleview.day.settingsView.times;
                        for (var i = 0; i < times.length; i++) {
                            
                           
                            if (time < times[i].time) {
                                return times[i - 1].allow;
                                }
                            if (time == times[i].time) {
                                return times[j].allow;
                             
                                 }
                        }
                    }
                    return false;
                }


            }],
            link: function (scope, element, attrs, ngModel) {
              
                if (!ngModel) return; // do nothing if no ng-model
                ngModel.$render = function () {
                    scope.theDayNum = ngModel.$viewValue;
                   
                };
            }
        };//return
    }
})(angular);


(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module("module.XCI.Device")
        .directive('zonesTable', zonesTableFactory);
    /********************************************************************************************************************************************************************/
    function zonesTableFactory() {


        const weekly = 'Weekly';


        return {
            restrict: 'EA',
            scope: {
                irrigationschedule: '='
            },
            templateUrl: 'app/modules.devices/XCI.Device/view/zonesTableDirectiveTemplate.html',
            controller: ['$scope', 'zoneProxy', '$locale', 'translate', '$filter', 'deviceProxy', '$state', 'mainRouter','user', function ($scope, zoneProxy, $locale, translate, $filter, deviceProxy, $state, mainRouter,user) {
                //********************************************Attribute*******************************************************
                $scope.locale = $locale;
                $scope.translate = translate;
                $scope.privilige = user.getSharingData().sharingData.roleModify;
                $scope.ladda = {
                    "tableLoad": false,
                    "byDay": false,
                    "byZone": false
                };
          
                $scope.type = translate.clockType($locale);
                ////*******************************************changeDeviceName****************************************************************
                $scope.changeDeviceName = function (id, newName) {
                    deviceProxy.changeDeviceName(id, newName)
                       .success(function (data) {
                          // toastr.success('changes saves', 'success!');
                       });
                }
                ////********************************************stringToUnix***************************************************************
                $scope.isAllowedTimeChanged = function (index, tb) {
                    $scope.newClickedIndex = index;
                    $scope.newClickedItem = tb;
                    var time = translate.stringToUnix(tb.firstStartTimeStr);
                    if (!isIrrigationTimeAllowed(index, time)) {
                        //popup
                        $('#timeNotAllowed').modal({
                            show: 'true'
                        })
                    } else {
                        $scope.irrigationschedule.titleDays[index].firstStartTime = time;
                        $scope.irrigationschedule.titleDays[index].numOfStartTime = 1;
                    }
                   
                  
                }
                //********************************************************************
                $scope.saveLastClickedItem = function (lastClickedItem , index) {
                    $scope.lastClickedIndex = index;
                    $scope.lastClickedItem = jQuery.extend(true, {}, lastClickedItem);
                }
                //******************************************************************
                $scope.allowAnyWay = function () {
                 
                    var time = translate.stringToUnix($scope.newClickedItem.firstStartTimeStr);
                    $scope.irrigationschedule.titleDays[$scope.newClickedIndex].firstStartTimeStr = $scope.newClickedItem.firstStartTimeStr;
                    $scope.irrigationschedule.titleDays[$scope.newClickedIndex].firstStartTime = time;
                    $scope.irrigationschedule.titleDays[$scope.newClickedIndex].numOfStartTime = 1;
                    $('#timeNotAllowed').modal('hide');
                }
                //*********************************************************************
                $scope.discardChanges = function () {

                    var time = translate.stringToUnix($scope.lastClickedItem.firstStartTimeStr);
                    $scope.irrigationschedule.titleDays[$scope.lastClickedIndex].firstStartTimeStr = $scope.lastClickedItem.firstStartTimeStr;
                    $scope.irrigationschedule.titleDays[$scope.lastClickedIndex].firstStartTime = time;
                    $scope.irrigationschedule.titleDays[$scope.lastClickedIndex].numOfStartTime = 1;
                    $('#timeNotAllowed').modal('hide');
                }
                //******************************************************************
                $scope.bodyValChange = function (tb) {
                    tb.duration = parseFloat(tb.durationStr)*60;
                }
                ////********************************************changeTableType**************************************************************         
                $scope.changeTableType = function (type) {
                    $scope.currentTableType = type;
                    $scope.ladda.tableLoad = true;
                    deviceProxy.changeTableType($scope.deviceId, type)
                       .success(function (data) {
                           $scope.schedualType = data.body.scheduleType;
                           if ($scope.schedualType != 'Weekly') {
                               $scope.irrigationschedule = $scope.parseSchedual(data.body);
                               mainRouter.callkey("saveScedual", $scope.irrigationschedule);
                           } else {
                               $scope.irrigationschedule = $scope.addTimeStrProperty(data.body);
                              mainRouter.callkey("saveScedual", $scope.irrigationschedule);
                           }
                           //toastr.success('changes saves', 'success!');
                           $scope.ladda.tableLoad = false;
                       });
                }
                ////******************************************addTimeStrProperty*****************************************************************         
                $scope.addTimeStrProperty = function (irrigationschedule) {
                    for (var i = 0; i < irrigationschedule.titleDays.length; i++) {
                        var time = $filter('date')(translate.convertUnixToTime(irrigationschedule.titleDays[i].firstStartTime), 'shortTime');
                        irrigationschedule.titleDays[i]['firstStartTimeStr'] = time;
                    }
                    for (var i = 0; i < irrigationschedule.zones.length; i++) {
                        for (var j = 0; j < irrigationschedule.zones[i].days.length; j++) {
                            var min = $scope.translate.secsToMinutes(irrigationschedule.zones[i].days[j].duration);
                            irrigationschedule.zones[i].days[j]['durationStr'] = min;
                        }
                    }
                    $scope.ladda.tableLoad = false;
                    return irrigationschedule;
                }
                ////************************************************getZone***********************************************************   
                $scope.getZone = function (zoneId, zoneName) {
                    //zone irrigation sceduale
                    $scope.currentZoneName = zoneName;
                    $scope.zoneId = zoneId;
                    zoneProxy.getZoneSchedule($scope.deviceId, zoneId)
                       .success(function (data) {
                           $scope.zoneScheduleView = data.body;
                       });
                }
                //***********************************************saveIrrigationByzoneSchedule*****************************
                $scope.saveIrrigationByzoneSchedule = function () {
                    //zone irrigation sceduale
                    $scope.ladda.byZone = true;
                    zoneProxy.saveTableIrrigationByZone($scope.deviceId, $scope.zoneId,"Weekly", $scope.zoneScheduleView)
                            .success(function (data) {
                               // toastr.success('changes saves', 'success!');
                                $scope.ladda.byZone = false;
                                $('#specificZoneModalDialog').modal('hide');
                            });
                }
                //************************************************NextZone****************************
                $scope.NextZone = function (zoneNumber) {
                    if (zoneNumber < $scope.zonesListLength) {
                        zoneNumber++;
                        zoneProxy.getZoneSchedule($scope.deviceId, zoneNumber)
                           .success(function (data) {
                               $scope.zoneScheduleView = data.body.scheduleView;
                               //run irrigation by zone directive , data.body.scheduleView must include zone name 
                               //$scope.currentZoneName = zoneName;
                               //$scope.zoneId = zoneId;
                           });
                    }
                }
                //***********************************************PrevZone*****************************
                $scope.PrevZone = function (zoneNumber) {
                    if (zoneNumber > 1) {
                        zoneNumber--;
                        zoneProxy.getZoneSchedule($scope.deviceId, zoneNumber)
                           .success(function (data) {
                               $scope.zoneScheduleView = data.body.scheduleView;
                               //run irrigation by zone directive
                           });
                    }
                }
                //**********************************************parseSchedual******************************
                $scope.parseSchedual = function (dayScheduleView) {
                    for (var i = 0; i <dayScheduleView.startTimes.length; i++) {
                        var time = $scope.translate.convertUnixToTime(dayScheduleView.startTimes[i].time);
                        var filterTime = $filter('date')(time, 'shortTime');
                        dayScheduleView.startTimes[i]['timeStr'] = filterTime;
                    }
                    for (var i = 0; i <dayScheduleView.zones.length; i++) {
                        for (var j = 0; j <dayScheduleView.zones[i].starts.length; j++) {
                            var min = $scope.translate.secsToMinutes(dayScheduleView.zones[i].starts[j].duration);
                            dayScheduleView.zones[i].starts[j]['durationStr'] = min;
                        }
                    }
                    $scope.zonesListLength = dayScheduleView.zones.length;
                    $scope.tableLoad = false;
                    return dayScheduleView;
                }
                //********************************************changeDay**********
                $scope.changeDay = function (day) {
                    //http get perDay object
                    deviceProxy.getDaySchedule($scope.deviceId, day)
                      .success(function (data) {
                          $scope.dayScheduleView = $scope.parseSchedual(data.body);
                          $scope.currentDayNum = day;
                      });
                }
                //*************************************NextDay***************************************************
                $scope.NextDay = function (day) {
                    if (day < 6) {
                        day++;
                        $scope.changeDay(day);
                    }
                    
                }
                //*************************************NextDay***************************************************
                $scope.PrevDay = function (day) {
                    if (day > 0) {
                        day--;
                        $scope.changeDay(day);
                    }
                }
                //*******************************************saveUsagePerDay*********************************
                $scope.saveUsagePerDay = function () {
                    $scope.ladda.byDay = true;
                    for (var i = 0; i < $scope.dayScheduleView.zones.length; i++) {
                        for (var j = 0; j < $scope.dayScheduleView.zones[i].starts.length; j++) {
                            $scope.dayScheduleView.zones[i].starts[j].duration = translate.minutesToSecs(parseInt($scope.dayScheduleView.zones[i].starts[j].durationStr))
                        }
                    }
                    //send the object
                    deviceProxy.saveDaySchedule($scope.deviceId,$scope.currentDayNum, $scope.dayScheduleView)
                      .success(function (data) {
                          $scope.changeTableType(1);
                          $scope.ladda.byDay = false;
                          $('#specificDayModalDialog').modal('hide');
                          toastr.success('changes saves', 'success!');
                         
                      });
                    
                }   
                //*****************************************************************************
                $scope.goToZone = function (zoneId) {
                    fixLoadingOn("ZoneAdviser");
                    $state.go('device.XCI_device.zones.adviser', { zoneId: zoneId });
                }
                //*********************************************************************************
                mainRouter.register("refreshTable", function (data) {
                    $scope.changeTableType(null);
                });
                //*******************************************************************************
                var isIrrigationTimeAllowed = function (dayNumber,startTime) {
                    if ($scope.currentTableType == 1) {
                        for (var i = 0; i < $scope.irrigationschedule.titleDays.length; i++) {
                            if ($scope.irrigationschedule.titleDays[i].dayNumber == dayNumber) {
                                var timesArray = $scope.irrigationschedule.titleDays[i].settingsView.times;
                                for (var j = 0; j < timesArray.length; j++) {
                                    if (startTime < timesArray[j].time) {
                                        return timesArray[j - 1].allow;
                                    }
                                    if (startTime == timesArray[j].time) {
                                        return timesArray[j].allow;
                                    }
                                }
                            }
                        }
                    }
                    return false;
                }
            }],
            link: function (scope, element, attrs, ngModel) {
                
                scope.deviceId = attrs.device;
                scope.schedualType = scope.irrigationschedule.scheduleType;
                if (scope.schedualType == weekly) {
                    scope.currentTableType = 1;
                    scope.irrigationschedule = scope.addTimeStrProperty(scope.irrigationschedule)
                } else {
                    scope.changeTableType(scope.schedualType);
                }
               
            }
        };      
    }
              /*******************************************************************************************************************************************************************************/

})(angular);


(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.httpProxies')
        .provider('deviceProxy', deviceProxy);


    //////////////// JavaScript //////////////

    function deviceProxy() {

       

        return {

            $get: ['$http', 'baseProxy', function ($http, baseProxy) {

                var data = baseProxy.Global.data.serverUri + '/Admin/Device';
                var xciServices = baseProxy.Global.data.serverXci + '/Admin/Device';
                var onlineServer = ROOT_ADDR.ONLINE_SERVER + '/online';
                ///////////////////////START DONE///////////////////////////////////////////////////////
                function _openAddAlerts(sn) {

                    return $http.get(xciServices + "/" + sn + "/AlertSettings");
                };
                function _switchDeviceAlerts(sn, isAlertsEnabled) {

                    return $http.post(xciServices + "/" + sn + "/AlertSettings?AlertEnabled=" + isAlertsEnabled);

                };
                function _CtrlAlertsSavings(sn , data1) {
               
                    return $http.post(xciServices + "/" + sn + "/AlertSettings", data1);

                };
                function _deleteCtrl(sn) {

                    return $http.delete(data + "/" + sn + "/Unlink");

                };
                function _SnValidation(sn, code) {

                    return $http.get(data + "/" + sn + "/Add/Verification?verificationCode=" + code);

                };
                function _NewCtrlSave(sn, data1) {
                    var obj = {};
                    obj.body = data1;

                    return $http.post(data + "/" + sn + "/Add/Submit", obj);

                };
                function _getZonesList(controllerId) {

                    return $http.get(data + "/" + controllerId + "/Zones");
                };
                function _changeDeviceName(sn, name) {
              

                    return $http.post(data + "/" + sn + "/Name/" + name);

                };
                function _getViewPage(sn) {


                    return $http.get(xciServices + "/" + sn);

                };


                function _getDeviceHoldData(sn) {
                    return $http.get(xciServices + "/" + sn + "/DeviceSettings");
                };

                function _saveDeviceHoldData(sn,obj) {
                    return $http.post(xciServices + "/" + sn + "/DeviceSettings" ,obj );
                };

                function _SaveSettings(sn, data1) {
                    var obj = {};
                    obj.body = data1;

                    return $http.post(xciServices + "/" + sn + "/Settings", obj);

                };
                function _SaveSchedule(sn, data1) {
                    return $http.post(xciServices + "/" + sn + "/Schedule/" + data1.scheduleType, data1);
                };

              
                /////////////////////END DONE///////////////////////////////////////////////////////////
              
                function _getDaySchedule(sn, day) {
                    return $http.get(xciServices + "/" + sn + "/Schedule/Weekly/" + day);

                };

                function _saveDaySchedule(sn, day, data1) {
                    return $http.post(xciServices + "/" + sn + "/Schedule/Weekly/" + day, data1);
                };

                function _changeTableType(sn, type) {
                    return $http.get(xciServices + "/" + sn + "/Schedule/?sType=" + type);
                };

                function _GetCoordinate(add) {
                    return $http.get('https://maps.googleapis.com/maps/api/geocode/json?address=' + add + '&key=' + baseProxy.Global.data.GoogleKey);
                };

                function _getZonesActivateList(sn) {
                    return $http.get(xciServices + "/" + sn + "/Zones");
                };

                function _activateZone(sn,data1) {
                    return $http.post(xciServices + "/" + sn + "/Zones" , data1);

                };

                function _getDaySetting(sn) {
                    return $http.get(xciServices + "/" + sn + "/DaySetting");

                };
                function _saveDaySetting(sn ,obj) {
                    return $http.post(xciServices + "/" + sn + "/DaySetting",obj);

                };
                function _saveAlertSetting(sn, obj) {
                    return $http.post(xciServices + "/" + sn + "/AlertThresholdSettings", obj);

                };

                //*******************online

                function _getDeviceOnline(sn) {
                    return $http.get(onlineServer + "/device/?deviceId=" + sn);
                };
                function _manualZoneOperationOnline(sn, zoneId,time) {
                    return $http.post(onlineServer + "/device/manualStart/?sn=" + sn+"&zoneId="+zoneId+"&time="+time);
                };
                









                //interface
                return {
                    openAddAlerts: _openAddAlerts,
                    switchDeviceAlerts: _switchDeviceAlerts,
                    CtrlAlertsSavings: _CtrlAlertsSavings,
                    deleteCtrl: _deleteCtrl,
                    SnValidation: _SnValidation,
                    NewCtrlSave: _NewCtrlSave,
                    getZonesList: _getZonesList,
                    changeDeviceName: _changeDeviceName,
                    getViewPage: _getViewPage,
                    SaveSettings: _SaveSettings,
                    getDaySchedule: _getDaySchedule,
                    changeTableType: _changeTableType,
                    SaveSchedule: _SaveSchedule,
                    saveDaySchedule:_saveDaySchedule,
                    GetCoordinate: _GetCoordinate,
                    getZonesActivateList: _getZonesActivateList,
                    activateZone: _activateZone,
                    getDeviceHoldData: _getDeviceHoldData,
                    saveDeviceHoldData: _saveDeviceHoldData,
                    getDaySetting: _getDaySetting,
                    saveDaySetting: _saveDaySetting,
                    saveAlertSetting: _saveAlertSetting,
                    getDeviceOnline: _getDeviceOnline,
                    manualZoneOperationOnline: _manualZoneOperationOnline
                };
            }]
        }
    }
})(angular);

(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.httpProxies')
        .provider('profileProxy', profileProxy);


    //////////////// JavaScript //////////////

    function profileProxy() {

        var data = {
            serverURI: ""
        }


        return {

            $get: ['$http', 'baseProxy', function ($http, baseProxy) {

                var data = baseProxy.Global.data.serverMF + '/Account';
                ///////////////////////START DONE///////////////////////////////////////////////////////
                function _acceptMessage(obj) {
                    return $http.post(data + "/Message?MessageID=" + obj.MessageID + "&MessagesStatus=" + obj.Status + "&ProjectID=" + obj.record.projectId + "&ProjectName=" + obj.record.projectName);

                };
                function _GetMessageNum() {
                    return $http.get(data + "/CountMessages");
                };
                
                function _GetMessages() {

                    return $http.get(data + "/GetMessages");

                };
                function _GetMessage(messageId) {

                    return $http.get(data + "/Message?MessageID=" + messageId);
                };
               
                function _loadCurrentProfile() {
                    return $http.get(ROOT_ADDR.SYSTEM_ACCOUNT_API + "/Account/Profile");
                };
              
        
                //interface
                return {
                    acceptMessage: _acceptMessage,
                    GetMessageNum:_GetMessageNum,
                    GetMessages: _GetMessages,
                    GetMessage: _GetMessage,
                    loadCurrentProfile: _loadCurrentProfile
           




                };
            }]
        }
    }
})(angular);

(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.httpProxies')
        .provider('projectProxy', projectProxy);


    //////////////// JavaScript //////////////

    function projectProxy() {

        var data = {
            serverURI: ""
        }


        return {

            $get: ['$http', 'baseProxy', function ($http, baseProxy) {

            //  var data = baseProxy.Global.data.serverUri + '/Admin/Project';

                var data = baseProxy.Global.data.serverMF + '/Admin/Project';
                ///////////////////////START DONE///////////////////////////////////////////////////////
                function _GetProjects(currentPage, freeText, PageSize) {
                  return $http.get(data + '/Tree/?PageNumber=' + currentPage + '&Search=' + freeText + '&PageSize=' + PageSize);
                };
                function _GetProjectsById(siteId, pageSize) {
                    return $http.get(data + '/Tree/'+siteId+'?PageSize=' + pageSize);
                };
                function _GetAllProjects() {
                    return $http.get(data + '/Projects');
                };
                function _saveNewProject(p, lat, lan) {
                   return $http.post(data + '/?ProjectName=' + p, baseProxy.buildLocation(lat, lan));
                };
                function _saveProjectSiteListAlert(p , data1) {
                    
                    return $http.post(data + '/' + p + '/Alerts', data1);
                };
                function _DeleteProject(id) {
                    return $http.delete(data + '/'+id);
                };
                function _getProjectAlerts(projectId, includeSub , pageNumber , pageSize) {
                    return $http.get(data + '/' + projectId + "/Alerts?IncludedSub=" + includeSub + "&PageNumber=" + pageNumber + "&PageSize="+pageSize);
                };
                function _macroAlerts(projectId, includeSub , status) {

                    return $http.post(data + '/' + projectId + "/MacroAlerts?IncludedSub=" + includeSub + "&Status=" + status);
                };
                function _postAlertsTableData(projectId,alerts) {

                    return $http.post(data + '/' + projectId + "/Alerts", alerts);
                };
                function _exchange() {
                    return $http.get(data + '/Exchange');
                };



             
           

                //interface
                return {

                    GetProjects: _GetProjects,
                    GetProjectsById:_GetProjectsById,
                    GetAllProjects:_GetAllProjects,
                    postAlertsTableData:_postAlertsTableData,
                    saveNewProject: _saveNewProject,
                    DeleteProject: _DeleteProject,
                    macroAlerts:_macroAlerts,
                    getProjectAlerts: _getProjectAlerts,
                    exchange: _exchange
                 
                  


                };
            }]
        }
    }
})(angular);

(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.httpProxies')
        .provider('siteProxy', siteProxy);


    //////////////// JavaScript //////////////

    function siteProxy() {

      

        return {

            $get: ['$http', 'baseProxy', function ($http, baseProxy) {

               var data1 = baseProxy.Global.data.serverUri + '/Admin/Site';
               var data = baseProxy.Global.data.serverMF + '/Admin/Site'
               var dataDevice = baseProxy.Global.data.serverMF + '/Admin/Device'
               var onlineServer = ROOT_ADDR.ONLINE_SERVER+'/online';
                ///////////////////////START DONE///////////////////////////////////////////////////////
                function _GetControllersLocation(siteId) {

                    return $http.get(data + "/" + siteId + "/Map");
    
                };
                function _SaveSiteLocation(s, z, Lat, Lan, typeMap, fitBounds) {
                   return $http.post(data + '/' + s + '/Location', baseProxy.saveManualMap(Lat, Lan, z, typeMap, fitBounds));
                  
                };

                function _SaveSiteDeviceChangeLocation(siteId, sn, deviceLat, deviceLan) {
                 return $http.post(data + "/" + siteId + "/Map/Devices/" + sn, baseProxy.buildPinLocation(deviceLat, deviceLan));
                    
                };
                function _GetsiteConT(siteId) {
                  return $http.get(data + "/" + siteId + "/Devices/");
             

                };
                function _CreateNewSite(p, s) {

                    return $http.post(data + '/?SiteName=' + s + '&ParentProjectID=' + p);
                   
                };
                function _switchDeviceAlerts(sn, isAlertsEnabled) {

                    return $http.post(dataDevice + "/" + sn + "/AlertSettings?AlertEnabled=" + isAlertsEnabled);

                };
                /////////////////////END DONE///////////////////////////////////////////////////////////
                function _GetWeatherDetails(siteId) {
                   return $http.get(data + "/" + siteId + "/Weather");
               

                };
                function _SaveSiteWeatherSettings(siteId,Data1) {

                    var obj = {};
                    obj.body = Data1;
                  return $http.post(data + "/" + siteId + "/Weather/Settings/", obj);
                  
                };
                function _GetDeviceType(deviceId) {
                    return $http.get(dataDevice + "/" + deviceId + "/Type");


                };
              
                function _getSiteName(siteId) {
                    return $http.get(data + "/" + siteId + "/Info");
                   // return $http.get(data + "/" + siteId + "/SiteToProject");
                };
                function _changeSiteName(id, name) {
                    return $http.post(data + '/'+id+'?SiteName=' + name);
                };
              
                function _DeleteSite(id) {
                    return $http.delete(data + '/' + id);
                };
                function _getSharingList(id) {
                    return $http.get(data + "/" + id + "/Users");
                };
                function _sendShareUser(id,data1) {
                    return $http.post(data + "/" + id + "/Users", data1);
                };
                function _deleteUser(siteId , userId) {
                    return $http.delete(data + "/" + siteId + "/Users?LinkedUserID=" + userId);
                };
                function _transferProject(id, email) {
                    return $http.post(data + "/" + id + "/Transfer?Email="+email);
                };
                function _getTransferStatus(id) {
                    return $http.get(data + "/" + id + "/Transfer");
                };
                function _cancelTransfer(id) {
                    return $http.delete(data + "/" + id + "/Transfer");
                };
                function _localTransfer(sId,target) {
                    return $http.post(data + "/" + sId + "/LocalTransfer?ProjectID=" + target);
                };


                function _GetDeviceInfo(deviceId) {
                    return $http.get(dataDevice + "/" + deviceId + "/Info");


                };
                function _getSessonList(siteID) {
                    return $http.get(data + "/" + siteID + "/SessionSetting");


                };
                function _saveSessonList(siteID, sessonList) {
                    return $http.post(data + "/" + siteID + "/SessionSetting",sessonList);
                };
              
                 function _getOneSesson(siteID , sessionID) {
                    return $http.get(data + "/" + siteID + "/SessionSetting/" + sessionID);
                };
                function _saveOneSesson(siteID, sessionID, obj) {
                    return $http.post(data + "/" + siteID + "/SessionSetting/" + sessionID,obj);
                };
                function _changeDeviceName(sn,name) {
                    return $http.post(dataDevice + "/" + sn+"/?name="+name);
                };
                function _getSiteOnlineStatus(sn) {
                    return $http.get(onlineServer + "/siteDevices/?siteId=" + sn);
                };
                function _saveDeviceLocation(sn, lat , lan) {
                    return $http.post(dataDevice + "/"+sn+ '/Location', {Latitude:lat,Longitude:lan});
                };



               

                //interface
                return {

                    GetControllersLocation: _GetControllersLocation,
                    SaveSiteLocation: _SaveSiteLocation,
                    SaveSiteDeviceChangeLocation: _SaveSiteDeviceChangeLocation,
                    GetDeviceInfo:_GetDeviceInfo,
                    GetsiteConT: _GetsiteConT,
                    CreateNewSite: _CreateNewSite,
                    switchDeviceAlerts:_switchDeviceAlerts,
                    GetWeatherDetails: _GetWeatherDetails,
                    SaveSiteWeatherSettings: _SaveSiteWeatherSettings,
                    GetDeviceType:_GetDeviceType,
                    getSiteName: _getSiteName,
                    changeSiteName: _changeSiteName,
                    DeleteSite: _DeleteSite,
                    getSharingList: _getSharingList,
                    sendShareUser: _sendShareUser,
                    deleteUser: _deleteUser,
                    transferProject: _transferProject,
                    getTransferStatus: _getTransferStatus,
                    cancelTransfer: _cancelTransfer,
                    localTransfer: _localTransfer,
                    getSessonList: _getSessonList,
                    saveSessonList: _saveSessonList,
                    getOneSesson: _getOneSesson,
                    saveOneSesson: _saveOneSesson,
                    changeDeviceName: _changeDeviceName,
                    saveDeviceLocation:_saveDeviceLocation,
                    getSiteOnlineStatus: _getSiteOnlineStatus

                    
                   


                };
            }]
        }
    }
})(angular);

(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.httpProxies')
        .provider('statsProxy', statsProxy);


    //////////////// JavaScript //////////////

    function statsProxy() {



        return {

            $get: ['$http', 'baseProxy', function ($http, baseProxy) {

                var data = baseProxy.Global.data.serverUri + '/Admin';
                ///////////////////////START DONE///////////////////////////////////////////////////////
           
                function _GetTopUsageLogSite(id, PageSize) {

                    return $http.get(data + "/Site/"+id+"/stats/Usage/?PageSize=" + PageSize);
                };
                function _getUsageLogSite(id, type,PageSize, date, currentPage) {

                    return $http.get(data + "/Site/" + id + "/stats/Usage/?PageSize=" + PageSize + "&PageNumber=" + currentPage + "&startDate=" + date.start + "&endDate=" + date.end);
                }
                function _GetTopAlertsLogSite(id, PageSize) {

                    return $http.get(data + "/Site/" + id + "/stats/Alerts/?PageSize=" + PageSize);
                };
                function _getAlertsLogSite(id, type, PageSize, date, currentPage) {

                    return $http.get(data + "/Site/" + id + "/stats/Alerts/?PageSize=" + PageSize + "&PageNumber=" + currentPage + "&startDate=" + date.start + "&endDate=" + date.end);
                }
                function _GetTopGeneralLogSite(id, PageSize) {

                    return $http.get(data + "/Site/" + id + "/stats/General/?PageSize=" + PageSize);
                };
                function _getGeneralLogSite(id, type, PageSize, date, currentPage) {

                    return $http.get(data + "/Site/" + id + "/stats/General/?PageSize=" + PageSize + "&PageNumber=" + currentPage + "&startDate=" + date.start + "&endDate=" + date.end);
                }
                function _getLinkData(id,sn, connectionId) {

                    return $http.get(data + "/Site/" + id +"/"+sn+ "/stats/General/" + connectionId);
                }
             
                function _GetStackDetails(id, from, to) {

                    return $http.get(data + "/Site/" + id + "/stats/Charts/?from=" + from + "&to=" + to);
                };









                //interface
                return {
                    GetTopUsageLogSite: _GetTopUsageLogSite,
                    getUsageLogSite: _getUsageLogSite,
                    GetTopAlertsLogSite: _GetTopAlertsLogSite,
                    getAlertsLogSite: _getAlertsLogSite,
                    GetTopGeneralLogSite: _GetTopGeneralLogSite,
                    getGeneralLogSite: _getGeneralLogSite,
                    getLinkData: _getLinkData,
                    GetStackDetails: _GetStackDetails
                





                };
            }]
        }
    }
})(angular);

(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.httpProxies')
        .provider('weatherProxy', weatherProxy);


    //////////////// JavaScript //////////////

    function weatherProxy() {



        return {

            $get: ['$http', 'baseProxy', function ($http, baseProxy) {


               // var data = baseProxy.Global.data.serverMF + '/Weather';
                var data = baseProxy.Global.data.serverMF + '/Weather'
                ///////////////////////START DONE///////////////////////////////////////////////////////
                function _GetWeatherDetails(id, time,param,location,type) {

                    if (location) {
                        return $http.get(data + "/" + id + "/Forecast?lon=" + location.lan + "&lat=" + location.lat + "&dateTicks=" + time + "&tempUnitID=" + type);
                    }
                    else if (param) {
                        return $http.get(data + "/" + id + "/ForecastSN?dateTicks=" + time);
                    } else {
                        return $http.get(data + "/" + id + "/Forecast?dateTicks=" + time);
                    }
                        
                };
                function _GetWeatherSettings(siteId) {

                    return $http.get(data + "/" + siteId + "/Setting");

                };
                function _SaveWeatherSettings(siteId, Data1, applyHierarchy) {
               
                    return $http.post(data + "/" + siteId + "/Setting?isSubSetting=" + applyHierarchy, Data1);

                };
                









                //interface
                return {

                    GetWeatherDetails: _GetWeatherDetails,
                    GetWeatherSettings:_GetWeatherSettings,
                    SaveWeatherSettings: _SaveWeatherSettings
                   
                };
            }]
        }
    }
})(angular);

(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.httpProxies')
        .provider('zoneProxy', zoneProxy);


    //////////////// JavaScript //////////////

    function zoneProxy() {



        return {

            $get: ['$http', 'baseProxy', function ($http, baseProxy) {

                var data = baseProxy.Global.data.serverUri + '/Admin/Device';
                var xciServices = baseProxy.Global.data.serverXci + '/Admin/Zone';
                ///////////////////////START DONE///////////////////////////////////////////////////////
                //function _updateZoneWireColor(controllerId, zoneId, value) {

                //    return $http.post(data + "/" + controllerId + "/Zones/" + zoneId + "?WireColor=" + value);
                //};
                function _updateZoneIsEnabled(controllerId, zoneId, value) {

                    return $http.post(data + "/" + controllerId + "/Zones/" + zoneId + "?IsEnabled=" + value);
                };
                function _updateZoneWeatherSavingAlgorithm(controllerId, zoneId, value) {

                    return $http.post(data + "/" + controllerId + "/Zones/" + zoneId + "?WeatherSavingAlgorithm=" + value);
                };
                function _updateZoneIrrigationFactor(controllerId, zoneId, value) {

                    return $http.post(data + "/" + controllerId + "/Zones/" + zoneId + "?IrrigationFactor=" + value);
                };
                function _getZoneDetails(sn, zoneId) {

                  
                    return $http.get(xciServices + "/" + sn + "/" + zoneId);
                };
                function _getZoneSchedule(sn, zoneId) {

                    return $http.get(xciServices + "/" + sn + "/" + zoneId + "/Schedule?sType=Weekly");
                   
                };
                function _getZoneSaggestionWizard(sn, zoneId) {

                    return $http.get(xciServices + "/" + sn + "/" + zoneId + "/ScheduleAdvisor");
                };
                function _saveSettings(controllerId, zoneId, settings) {
                 
                    return $http.post(xciServices + "/" + controllerId + "/" + zoneId + "/Settings", settings);
                };
                function _flowSensorSettings(controllerId, zoneId, flowSensorSettings) {
                  
                    return $http.post(xciServices + "/" + controllerId + "/" + zoneId + "/FlowSensorSettings", flowSensorSettings);
                };
                function _saveAndGetRecommendation(sn, zoneId , obj) {

                    return $http.post(xciServices + "/" + sn + "/" + zoneId + "/ScheduleAdvisor" , obj);
                };
                function _saveSuggestions(controllerId, zoneId, current) {
                    var obj = {
                        body: {
                            types: current
                        }
                    };
                    
                    return $http.post(data + "/" + controllerId + "/Zones/" + zoneId + "/ScheduleAdvisor", obj);
                };
                function _manualStartIrrigation(controllerId, zoneId, resetTime) {

                    var obj = {
                        body: {
                            time: resetTime
                        }
                    };
                    
                    return $http.post(data + "/" + controllerId + "/Zones/" + zoneId + "/manualStartIrrigation", obj);
                };
                function _saveTableIrrigationByZone(sn, zoneId,type, IrrigationByZone) {
             
                    return $http.post(xciServices + "/" + sn + "/" + zoneId + "/Schedule/" + type, IrrigationByZone);
                };

                function _getIrrigationSuggestion(sn, zoneId) {

                    return $http.get(xciServices + "/" + sn + "/" + zoneId + "/IrrigationSuggestion");

                };
                function _getZoneInfo(sn, zoneId) {

                    return $http.get(xciServices + "/" + sn + "/" + zoneId + "/ZoneInfo");

                };
                function _acceptSuggestions(sn, zoneId) {
                    return $http.post(xciServices + "/" + sn + "/" + zoneId + "/AcceptSuggestion");
                };
                function _changeZoneName(sn,zoneId, name) {
                    return $http.post(xciServices + "/" + sn + "/" + zoneId + "?Name="+name);
                };







                //interface
                return {
                   // updateZoneWireColor: _updateZoneWireColor, //not in use
                    updateZoneIsEnabled: _updateZoneIsEnabled,//not in use
                    updateZoneIrrigationFactor: _updateZoneIrrigationFactor,//not in use
                    updateZoneWeatherSavingAlgorithm: _updateZoneWeatherSavingAlgorithm,//not in use
                    getZoneDetails: _getZoneDetails,
                    getZoneSchedule:_getZoneSchedule,
                    saveSettings: _saveSettings,
                    flowSensorSettings:_flowSensorSettings,
                    getZoneSaggestionWizard: _getZoneSaggestionWizard,
                    acceptSuggestions: _acceptSuggestions,
                    saveAndGetRecommendation: _saveAndGetRecommendation,
                    manualStartIrrigation: _manualStartIrrigation,//not in use
                    saveTableIrrigationByZone: _saveTableIrrigationByZone,
                    getIrrigationSuggestion: _getIrrigationSuggestion,
                    getZoneInfo: _getZoneInfo,
                    changeZoneName: _changeZoneName








                };
            }]
        }
    }
})(angular);

(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site.preview')
        .directive('calandar', calandarFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function calandarFactory() {

        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.site/module.preview/calandar/calandar.html',

            controller: ['$scope', '$http', '$filter', '$stateParams', 'siteProxy', 'deviceProxy', function ($scope, $http, $filter, $stateParams, siteProxy, deviceProxy) {

                //************************************************Attributs*******************

                //************************************************functions*******************

                //***********************GetsiteConT(Inner)******************
                function GetsiteConT(param) {
                    siteProxy.GetsiteConT(param)
                       .success(function (data) {

                           $scope.controllers = data;
                           $scope.flag1 = true;
                           fixLoadingOff();
                       }).error(function (data, status, headers, config) {
                           toastr.error($filter('translate')('toastrErrMsgGet'));
                           fixLoadingOff();
                       });
                }

                $scope.choosenDevice = function (sn) {

                    siteProxy.GetDeviceInfo(sn)
                        .success(function (data) {
                            $scope.currentDevice = data.body;


                        }).error(function (data, status, headers, config) {
                            toastr.error($filter('translate')('toastrErrMsgGet'));
                        });
                }




                GetsiteConT($stateParams.siteId);

            }
            ]
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);








(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site.preview')
       .directive('graph', graphFactory);
    /*******************************************************************************************************************************************************************/
    function graphFactory() {


        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.site/module.preview/graph/graph.html',
            link: function (scope, element, attrs, ngModel) {


                

                google.charts.load('current', { 'packages': ['corechart'] });
                google.charts.setOnLoadCallback(drawTwoYears);
                google.charts.setOnLoadCallback(drawTop5);
                google.charts.setOnLoadCallback(drawTop10);

                var color = localStorage.getItem('cssType') == 'dark' ? 'white' : 'grey';

                //*************************************************
                function drawTop10() {
                    var data = google.visualization.arrayToDataTable([
                        ['Month', '2015'],
                        ['Back Garden', 165],
                        ['James Home', 135],
                        ['Agamin Pool', 157],
                        ['Rear Garden', 139],
                        ['Front Swimming Pool', 136]
                    
                   
                       
                    ]);

                    var options = {
                        title: 'Top 10 Largest Consumers This Month',
                        colors: ['green'],
                        titleTextStyle: { position: 'center', color: color, fontSize: '15' },
                        legend: {position: 'none'},
                        vAxis: { title: 'Unit Name', textStyle: { color: color } },
                        hAxis: { title: 'Gallon', textStyle: { color: color } },
                        backgroundColor: 'transparent',
                        is3D: true,
                     

                    };

                    var chart = new google.visualization.BarChart(document.getElementById('Top10'));
                    chart.draw(data, options);
                }
                //*************************************************
                function drawTop5() {
                    // Some raw data (not necessarily accurate)
                    var data = google.visualization.arrayToDataTable([
                         ['Month', '2015', '2016'],
                         ['1', 165, 938],
                         ['2', 135, 1120],
                         ['3', 157, 1167],
                         ['4', 139, 1110],
                         ['5', 136, 691],
                         ['6', 136, 1167],
                         ['7', 136, 691],
                         ['8', 136, 1167],
                         ['9', 136, 691],
                         ['10', 136, 691],
                         ['11', 136, 1167],
                         ['12', 136, 691]
                    ]);

                    var options = {
                        title: '2 Years Project Consumption',
                        colors: ['#e0440e', '#e6693e'],
                        titleTextStyle: {position: 'center', color: color, fontSize: '15' },
                        legend: { position: 'top', textStyle: { fontSize: '12', color: color } },
                        vAxis: { title: 'Gallon', textStyle: { color: color } },
                        hAxis: { title: 'Month', textStyle: { color: color } },
                        backgroundColor: 'transparent',
                        is3D:true,
                        seriesType: 'bars',
                        series: { 2: { type: 'line' } }
                       
                    };

                    var chart = new google.visualization.ComboChart(document.getElementById('TopFive'));
                    chart.draw(data, options);
                }
                //*************************************************
                function drawTwoYears() {
                    // Some raw data (not necessarily accurate)
                    var data = google.visualization.arrayToDataTable([
                         ['Month', '2015', '2016'],
                         ['1', 165, 17],
                         ['2', 135, 112],
                         ['3', 1157, 4167],
                         ['4', 139, 456],
                         ['5', 567, 890],
                         ['6', 28, 356],
                         ['7', 800, 67],
                         ['8', 456, 543],
                         ['9', 234, 100],
                         ['10', 345, 500],
                         ['11', 1000, 189],
                         ['12', 600, 456]
                    ]);

                    var options = {
                        title: '2 Years Project Consumption',
                        titleTextStyle: {position: 'center', color: color, fontSize: '15' },
                        legend: { position: 'top', textStyle: { fontSize: '12', color: color } },
                        vAxis: { title: 'Gallon', textStyle: { color: color } },
                        hAxis: { title: 'Month', textStyle: { color: color } },
                        backgroundColor: 'transparent',
                        is3D:true,
                        seriesType: 'bars',
                        series: { 2: { type: 'line' } }
                    };

                    var chart = new google.visualization.ComboChart(document.getElementById('TwoYears'));
                    chart.draw(data, options);
                }








            }
        };



    }
    /*******************************************************************************************************************************************************************************/

})(angular);








(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    siteConTFactory.$inject = ['$log'];
    angular.module('module.site.preview')
        .directive('siteConT', siteConTFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function siteConTFactory($log) {

        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.site/module.preview/list/listDirectiveTemplate.html',

            controller: ['$scope', '$http', '$filter', '$stateParams', '$state', 'siteProxy', 'deviceProxy', 'user', 'mainProvider', 'onlineProvider', function ($scope, $http, $filter, $stateParams, $state, siteProxy, deviceProxy, user, mainProvider, onlineProvider) {
              //  $scope.privilige = user.getSharingData().sharingData.roleModify;
                //************************************************Attributs*******************
                $scope.laddaAlerts = false;
                var OnlineEvents = ['1000'];
                //************************************************functions*******************
                function onlineCBfuncDEviceList(data) {
                    switch (String(data.code)) {
                        case "1000":
                            for (var i = 0; i < $scope.controllers.length; i++) {
                                if ($scope.controllers[i].sn == data.sn) {
                              
                                    if (!data.connection) {
                                        $scope.controllers[i].icon = '../../../../../Files/content/img/grey-dot.png';
                                    }
                                    if (data.connection) {
                                        $scope.controllers[i].icon = '../../../../../Files/content/img/green-dot.png';
                                    }
                                    if (data.connection && data.isFailure) {
                                     
                                        $scope.controllers[i].icon = '../../../../../Files/content/img/green-dot-Alert.png';
                                    }
                                    if (data.connection && data.isIrrigating) {
                                   
                                        $scope.controllers[i].icon = '../../../../../Files/content/img/green-dot-Irrigate.png';
                                    }
                                    if (data.connection && data.isFertilizing) {
                                        
                                        $scope.controllers[i].icon = '../../../../../Files/content/img/green-dot-Fertilizing.png';
                                    }
                                   
                                }
                            }
                         //   $scope.$apply();
                            break;
                    }
               
                  
                }
                //***********************GetsiteConT(Inner)******************
                function GetsiteConT (param) {
             
                    siteProxy.GetsiteConT(param)
                       .success(function (data) {
                         
                           
                      
                           $scope.controllers = data.body;
                           for (var i = 0; i < $scope.controllers.length; i++) {
                               $scope.controllers[i].icon = '../../../../../Files/content/img/grey-dot.png';
                               
                           }
                           $scope.start = true;
                           fixLoadingOff();
                           onlineProvider.registerSite(OnlineEvents,param, 'siteList', onlineCBfuncDEviceList);
                       }).error(function (data, status, headers, config) {
                           toastr.error($filter('translate')('toastrErrMsgGet'));
                           fixLoadingOff();
                       });
                }
                //***********************openAddAlerts(Outer)****************
                $scope.openAddAlerts = function (param) {

                    deviceProxy.openAddAlerts(param)
                    .success(function (data) {
                      $scope.deviceSn = param;
                      $scope.alerts = data.body;
                    });
                }
                //***********************switchDeviceAlerts(Outer)***********
                $scope.switchDeviceAlerts = function (isAlert) {
                    isAlert.tb.isAlertsEnabled = !isAlert.tb.isAlertsEnabled;
                    siteProxy.switchDeviceAlerts(isAlert.tb.sn, isAlert.tb.isAlertsEnabled)
                    .success(function (data, status, headers, config) {
                        toastr.success('Changes Saves', 'Success!');
                    }).error(function (data, status, headers, config) {
                        toastr.error($filter('translate')('toastrErrMsgGet'));
                    });
                };
                //***********************saveAlerts(Outer)*******************
                $scope.saveAlerts = function (func) {
                    $scope.laddaAlerts = true;
                    deviceProxy.CtrlAlertsSavings($scope.deviceSn, $scope.alerts)
                        .success(function (data, status, headers, config) {
                            toastr.success('Changes Saves', 'Success!');
                            $scope.laddaAlerts = false;
                            func();
                        })
                        .error(function (data, status, headers, config) {
                            toastr.error($filter('translate')('toastrErrMsgGet'));
                        });
                }
                //**************************goToDevice(outer)***********************
                $scope.goToDevice = function (sn) {
                    fixLoadingOn("goToDevice", sn);
                    siteProxy.GetDeviceType(sn)
                        .success(function (data) {
                            $scope.device = data.body;
                            
                            switch ($scope.device.name) {
                                case "GSI":
                                    $state.go('device.GSI_device.status', { deviceId: sn});
                           
                                    break;
                                case "GSI-AG":
                                    $state.go('device.GSI_device.status', { deviceId: sn});
                                 
                                    break;
                                case "XCI-WIFI":
                                    $state.go('device.XCI_device.online', { deviceId: sn});
                                
                                    break;
                                case "XCI":
                                    $state.go('device.XCI_device.online', { deviceId: sn});
                           
                                    break;
                            }

                        }).error(function (data, status, headers, config) {
                            toastr.error($filter('translate')('toastrErrMsgGet'));
                        });
                }


                GetsiteConT($stateParams.siteId);

                

            }          
        ]};
    }

    /*******************************************************************************************************************************************************************************/

})(angular);








(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site.preview')
        .directive('mapSite', ['coordinator', 'baseProxy','siteProxy', '$state', 'user', '$filter', 'mainProvider', 'mainRouter', 'onlineProvider', mapFactory]);
    /*********************************************************************Weather****************************************************************************************************/
    function mapFactory(coordinator, baseProxy, siteProxy, $state, user, $filter, mainProvider, mainRouter, onlineProvider) {
        var latlngbounds;
        var markers = [];
        var map = null;
        var autoBoundsCenter;
        var OnlineEvents = ['1000'];
        //**************************************************goToDevice(Outer)*****************
        function goToDevice(deviceId, type) {

            switch (type) {
                case "GSI":
                    $state.go('device.GSI_device.online', { deviceId: deviceId});
                

                    break;
                case "GSI-AG":
                    $state.go('device.GSI_device.online', { deviceId: deviceId});
                  
                    break;
                case "XCI-WIFI":
                    $state.go('device.XCI_device.online', { deviceId: deviceId});
               
                    break;
                case "XCI":
                    $state.go('device.XCI_device.online', { deviceId: deviceId});
                    
                    break;
            }



        }
        //************************************************************************************
        function navigate(location) {


            // If it's an iPhone..
            if ((navigator.platform.indexOf("iPhone") != -1)
                || (navigator.platform.indexOf("iPod") != -1)
                || (navigator.platform.indexOf("iPad") != -1)) {
                return "http://maps://maps.google.com/maps?daddr=" + location.lat() + "," + location.lng() + "&amp;ll=";
            }
            else {
                return "http://maps.google.com/maps?daddr=" + location.lat() + "," + location.lng() + "&amp;ll=";
            }
        };


        return {
            restrict: 'EA',
            require: '?ngModel',
            transclude: true,
            template: '<div id="map-canvas-site"></div> ',
            replace: true,
            controller: ['$scope', '$state', 'baseProxy', 'translate', function ($scope, $state, baseProxy, translate) {
                
   
    
             
               
                //*************************************
                function goToDevice(deviceId, type) {
                    switch (type) {
                        case "GSI":
                            $state.go('device.GSI_device.online', { deviceId: deviceId, typeName: "GSI" });
           

                            break;
                        case "GSI-AG":
                            $state.go('device.GSI_device.online', { deviceId: deviceId, typeName: "GSI-AG" });
                    
                            break;
                        case "XCI-WIFI":
                            $state.go('device.XCI_device.online', { deviceId: deviceId, typeName: "XCI-WIFI" });
          
                            break;
                        case "XCI":
                            $state.go('device.XCI_device.online', { deviceId: deviceId, typeName: "XCI" });
            
                            break;
                    }
                }
                //*************************************
                function navigate(location) {
                    // If it's an iPhone..
                    if ((navigator.platform.indexOf("iPhone") != -1)
                        || (navigator.platform.indexOf("iPod") != -1)
                        || (navigator.platform.indexOf("iPad") != -1)) {
                        return "http://maps://maps.google.com/maps?daddr=" + location.lat() + "," + location.lng() + "&amp;ll=";
                    }
                    else {
                        return "http://maps.google.com/maps?daddr=" + location.lat() + "," + location.lng() + "&amp;ll=";
                    }
                };
                //*************************************
                function onlineCBfuncMap(data) {
                    switch (String(data.code)) {
                        case "1000":
                            for (var i = 0; i < markers.length; i++) {
                                if (markers[i].sn == data.sn) {
                                    //markers[i].data = data;
                                    if (!data.connection) {
                                        markers[i].iconUrl = '../../../../../Files/content/img/grey-dot.png';
                                        markers[i].markerObject.setIcon({ url: '../../../../../Files/content/img/grey-dot.png' });
                                    }
                                    if (data.connection) {
                                        markers[i].iconUrl = '../../../../../content/img/green-dot.png';
                                        markers[i].markerObject.setIcon({ url: '../../../../../Files/content/img/green-dot.png' });
                                    }
                                    if (data.connection && data.isFailure) {
                                        markers[i].iconUrl = '../../../../../content/img/green-dot-Alert.png';
                                        markers[i].markerObject.setIcon({ url: '../../../../../Files/content/img/green-dot-Alert.png' });
                                    }
                                    if (data.connection && data.isIrrigating) {
                                        markers[i].iconUrl = '../../../../../content/img/green-dot-Irrigate.png';
                                        markers[i].markerObject.setIcon({ url: '../../../../../Files/content/img/green-dot-Irrigate.png' });
                                    }
                                    if (data.connection && data.isFertilizing) {
                                        markers[i].iconUrl = '../../../../../content/img/green-dot-Fertilizing.png';
                                        markers[i].markerObject.setIcon({ url: '../../../../../Files/content/img/green-dot-Fertilizing.png' });
                                    }



                                }
                            }
                            break
                    }
                }

              
                //*****************************************************

                $scope.GetControllersLocation = function (siteId) {
                    siteProxy.GetControllersLocation(siteId)
                       .success(function (data) {
                           $scope.mapData = data.body;
                           $scope.createMarkers($scope.mapData.devices, $scope.mapData.location.mode);
                           onlineProvider.registerSite(OnlineEvents, siteId, 'siteMap', onlineCBfuncMap);
                       });
                }
                //***************************************
                function showPosition(position) {
                    map.setCenter({ lat: position.coords.latitude, lng: position.coords.longitude });// get current location
                }
                //**************************************
                $scope.getLocation = function () {    // if no devices 
                    map.setZoom(16);
                    if (navigator.geolocation) {
                        navigator.geolocation.getCurrentPosition(showPosition);
                    } else {
                        map.setCenter({ lat: 32.4 , lng: 33.8 }); // if gps not allowd
                    }
                }
                //****************************************
               
            }],
            link: function (scope, element, attrs, ngModel) {
                var privilige = user.getSharingData().sharingData;
                if (!ngModel) return; // do nothing if no ng-model
                ngModel.$render = function () {
                    scope.SiteId = ngModel.$viewValue;
                    scope.createMap();
                    scope.GetControllersLocation(scope.SiteId);
                };
                //****************************************************
                function SaveSiteDeviceChangeLocation(devices,deviceId, deviceLat, deviceLan) {
                    siteProxy.SaveSiteDeviceChangeLocation(scope.siteId,deviceId, deviceLat, deviceLan)
                          .success(function (data) {
                              toastr.success('Device Change Location Saved', 'Success!');
                              calculateSiteLocation(devices);
                              
                          });
                }
                //**************************************************************************
                scope.broadcastMapLocationChanged = function (siteCenter) {
                    coordinator.PublishEvent("SiteLocationChanged", siteCenter);
                }
                //*****************************************************
                scope.SaveSiteLocation = function () {

                    var typeMap = map.getMapTypeId();
                    scope.zoomLevel = map.getZoom();
                    scope.center = map.getCenter();

                    siteProxy.SaveSiteLocation(scope.siteId, scope.zoomLevel, scope.center.lat(), scope.center.lng(), typeMap, scope.UseAutoBounds)
                          .success(function (data) {
             
                          });
                }
                //*******************************************************************************
                function useAutomaticBounds(AutomaticBounds) {
                    var AutoUI = document.createElement('div');
                    AutoUI.style.backgroundColor = '#fff';
                    AutoUI.style.border = '2px solid #fff';
                    AutoUI.style.borderRadius = '3px';
                    AutoUI.style.boxShadow = '0 2px 6px rgba(0,0,0,.3)';
                    AutoUI.style.cursor = 'pointer';
                    AutoUI.style.marginBottom = '5px';
                    AutoUI.style.width = '60px';
                    AutoUI.style.height = '34px';
                    AutoUI.style.margin = '7px 7px 0px 0px';
                    AutomaticBounds.appendChild(AutoUI);
                    var controlText = document.createElement('div');
                    controlText.style.color = 'rgb(25,25,25)';
                    controlText.style.fontFamily = 'Roboto,Arial,sans-serif';
                    controlText.style.fontSize = '14px';
                    controlText.style.lineHeight = '28px';
                    controlText.style.paddingLeft = '5px';
                    controlText.style.paddingRight = '5px';
                    controlText.style.width = '60px';
                    controlText.style.height = '34px';
                    controlText.innerHTML = 'Center';
                    AutoUI.appendChild(controlText);
                    google.maps.event.addDomListener(AutoUI, 'click', function () { //auto bounds
                        map.setCenter(autoBoundsCenter);
                        map.fitBounds(latlngbounds);
                    });
                }
                //****************************************************
             
                scope.createMap = function () {
                    var mapOptions = {
                        //center: new google.maps.LatLng(centerLat, centerLn),
                        zoom: 8,
                        mapTypeId: google.maps.MapTypeId.ROADMAP
                    };
                    map = new google.maps.Map(element[0], mapOptions);

                    var AutomaticBounds = document.createElement('div');
                    useAutomaticBounds(AutomaticBounds);
                    AutomaticBounds.index = 1;
                    map.controls[google.maps.ControlPosition.RIGHT_TOP].push(AutomaticBounds);


                    
               
                }

                function calculateSiteLocation(devices){

                    if (devices.length == 0) {
                        scope.getLocation();
                    } else {
                        latlngbounds = new google.maps.LatLngBounds();
                        for (var i = 0; i < devices.length; i++) {
                            latlngbounds.extend(devices[i].myLatlng);
                        }
                        autoBoundsCenter = latlngbounds.getCenter();
                        map.setCenter(autoBoundsCenter);
                        map.fitBounds(latlngbounds);
                        scope.SaveSiteLocation();
                        var siteLocCenter = {
                            lat: autoBoundsCenter.lat(),
                            lan: autoBoundsCenter.lng()
                        }
                        scope.broadcastMapLocationChanged(siteLocCenter);
                        

                    }
                }
                //********************************************************
                scope.createMarkers = function (devices ,mapType) {
                    markers = [];
                    var geocoder = geocoder = new google.maps.Geocoder();
                    if (mapType == "roadmap") {
                        map.setMapTypeId(google.maps.MapTypeId.ROADMAP);
                    } else {
                        map.setMapTypeId(google.maps.MapTypeId.HYBRID);
                    }
                    //****************
                    for (var i = 0; i < devices.length; i++) {
                        var myLatlng = new google.maps.LatLng(devices[i].location.latitude, devices[i].location.longitude);
                        devices[i].myLatlng = myLatlng;
                        var marker = new google.maps.Marker({
                            position: myLatlng,
                            map: map,
                            ControllerId: devices[i].sn,
                            type: devices[i].deviceType,
                            draggable: devices[i].sharingData.roleModify,

                            animation: google.maps.Animation.DROP
                        });
                        var pushObject = {
                            markerObject: marker,
                            sn: devices[i].sn
                        }
                        markers.push(pushObject);
                      
                 
                        (function (marker) {
                            //get device name
                            google.maps.event.addListener(marker, "click", function (e) {
                                var navigateUrl = navigate(marker.position);
                                if (marker.type == 'GSI' || marker.type == 'GSI-AG') {
                                    var controllerAddress = "/#/device/" + marker.ControllerId + "/" + marker.type + "/status";
                                } else if (marker.type == 'XCI' || marker.type == 'XCI-WIFI') {
                                    var controllerAddress = "/#/device/" + marker.ControllerId + "/type/" + marker.type + "/online";
                                }
                                var contentString =
                               '<div class="nevigationWindow">' +
                               '<br/>' +
                               '<h6>Device:</h6>' +
                               '<a href=' + controllerAddress + '>' + marker.ControllerId + '</a>' +
                               '<hr>' +
                               '<i class="fa  fa-key marginRight7"></i><span>' + marker.type + '</span><br/>' +
                               '<i class="fa fa-map-marker marginRight7"></i><a href=' + navigateUrl + '>Navigate to device</a>'
                                var infowindow = new google.maps.InfoWindow({
                                    content: contentString,
                                    maxWidth: 270
                                });
                                infowindow.open(map, marker);

                            });
                            google.maps.event.addListener(map, 'maptypeid_changed', function () {
                                var privilige = user.getSharingData().sharingData;
                                if (privilige.roleModify) {
                                    scope.SaveSiteLocation(map);
                                }
                            });
                            google.maps.event.addListener(marker, "dblclick", function (e) {
                                goToDevice(marker.ControllerId, marker.type);
                            });
                            var sharingData = user.getSharingData();
                            google.maps.event.addListener(marker, "dragend", function (e) {
                                var lat, lng, address;
                                geocoder.geocode({ 'latLng': marker.getPosition() }, function (results, status) {
                                    if (status == google.maps.GeocoderStatus.OK) {
                                 
                                        SaveSiteDeviceChangeLocation(devices,marker.ControllerId, marker.getPosition().lat(), marker.getPosition().lng());
                                        for (var i = 0; i < devices.length; i++) {
                                            if (marker.ControllerId == devices[i].sn) {
                                                devices[i].location.latitude = marker.getPosition().lat();
                                                devices[i].location.longitude = marker.getPosition().lng();
                                                devices[i].myLatlng = new google.maps.LatLng(marker.getPosition().lat(), marker.getPosition().lng());
                                                }
                                            break;
                                        }
                                        calculateSiteLocation(devices);
                                    }
                                });

                            });

                        })(marker);
                       

                    }
                    calculateSiteLocation(devices);
                    fixLoadingOff();
                  
                }
               
            }
        };
    }
})(angular);








(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site.preview')
        .directive('squares', squaresFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function squaresFactory() {

        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.site/module.preview/squares/squares.html',

            controller: ['$scope', '$http', '$filter', '$stateParams', 'siteProxy', 'deviceProxy', '$state', function ($scope, $http, $filter, $stateParams, siteProxy, deviceProxy, $state) {

                //************************************************Attributs*******************

                //***********************GetsiteConT(Inner)***********************************
                function GetsiteConT(param) {
                    siteProxy.GetsiteConT(param)
                       .success(function (data) {

                           $scope.controllers = data.body;
                           fixLoadingOff();

                       }).error(function (data, status, headers, config) {
                           toastr.error($filter('translate')('toastrErrMsgGet'));
                           fixLoadingOff();
                       });
                }
                /******************************************************************************/
                function switchType(type, sn, param) {
                    mainProvider.ExchangeNevigation.data.type = "type";
                    switch (type) {
                      
                        case "GSI":
                            if (param == null) {
                                $state.go('site.preview.gsiOnline');
                            } else {
                                $state.go('device.GSI_device.status', { deviceId: sn});
                            }
                            
                            break;
                        case "GSI-AG":
                            if (param == null) {
                                $state.go('site.preview.gsiOnline');
                            } else {
                                $state.go('device.GSI_device.status', { deviceId: sn});
                            }
                            break;
                        case "XCI-WIFI":
                            if (param == null) {
                                $state.go('device.XCI_device.online', { deviceId: sn});
                            } else {
                                $state.go('device.XCI_device.online', { deviceId: sn});
                            }
                            break;
                        case "XCI":
                            if (param == null) {
                                $state.go('device.XCI_device.online', { deviceId: sn});
                            } else {
                                $state.go('device.XCI_device.online', { deviceId: sn});
                            }
                            break;
                    }
                }
                /*****************************************************************/
                $scope.goToOnlineView = function (device) {
                   // fixLoadingOn("goToDevice", device.sn);
                    switchType(device.deviceType, device.sn,'inDevice');

                }
                //*****************************************************************
                
                $scope.goToShortOnline = function (device) {
                    
                    switchType(device.deviceType,device.sn ,null);

                }
              


                /****************************************************************/
                GetsiteConT($stateParams.siteId);

            }
            ]
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);








(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site.preview')
        .directive('season', seasonFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function seasonFactory() {
        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.site/module.settings/season.html',
            scope: {
                comm: '='
            },
            controller: ['$scope', '$locale', 'translate', '$filter', 'siteProxy', '$stateParams', function ($scope, $locale, translate, $filter, siteProxy, $stateParams) {
                //*************************************Attributs*************************************
                $scope.type = translate.clockType($locale);
                $scope.siteId = $stateParams.siteId;
                //*************************************setTime(Inner)********************************
                //function setTime(seasson) {
                //    for (var i = 0; i < $scope.seasson.listDays.length; i++) {
                //        $scope.seasson.listDays[i].StartTimeStr = $filter('date')(translate.convertUnixToTime($scope.seasson.listDays[i].startTimeSeconds), 'shortTime');
                //        $scope.seasson.listDays[i].EndTimeStr = $filter('date')(translate.convertUnixToTime($scope.seasson.listDays[i].endTimeSeconds), 'shortTime');
                //        if ($scope.seasson.listDays[i].maxDailyIrrigrationSeconds) {
                //            $scope.seasson.listDays[i].MaxMinutesStr = $scope.seasson.listDays[i].maxDailyIrrigrationSeconds / 60;
                //        } else {
                //            $scope.seasson.listDays[i].MaxMinutesStr = 0;
                //        }

                //    }
                //}
                //***************************************************************
                $scope.changeTime = function (index, param) {
                    if (param == 'start') {
                        $scope.seasson.listDays[index].startTimeSeconds = translate.stringToUnix($scope.seasson.listDays[index].StartTimeStr);
                    } else {
                        $scope.seasson.listDays[index].endTimeSeconds = translate.stringToUnix($scope.seasson.listDays[index].EndTimeStr);
                    }
                }
                //*************************************************
                $scope.changeMinutes = function (index) {

                    $scope.seasson.listDays[index].maxDailyIrrigrationSeconds = parseInt($scope.seasson.listDays[index].MaxMinutesStr) * 60;

                }
                //***********************************************************
                $scope.comm.SetCallbackDown(function (seasson) {
                    $scope.seasson = seasson;
                    //setTime();

                });
                //***********************************************************
                $scope.saveOneSesson = function () {
                    siteProxy.saveOneSesson($scope.siteId, $scope.seasson.sessionID, $scope.seasson.listDays)
                                      .success(function (data) {
                                          var s = 8;
                                      });

                }

            }],
            link: function (scope, element, attrs) {
                scope.attr = attrs.param;    //site or device

            }




        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);








(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    siteAdDFactory.$inject = ['$log'];
    angular.module('module.site.settings')
        .directive('siteAdD', siteAdDFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function siteAdDFactory($log) {



        return {
            restrict: 'EA',
            require: '?ngModel',
            templateUrl: 'app/modules/module.site/module.settings/settings.html',

            controller: ['$scope', '$stateParams', 'projectProxy', 'baseProxy', 'siteProxy', '$filter', 'user', 'directiveComm', 'translate', function ($scope, $stateParams, projectProxy, baseProxy, siteProxy, $filter, user, directiveComm,translate) {

               
                $scope.daySettingConnector = directiveComm.CreateConnector();
                $scope.transferType = "Outer";
                $scope.isValid = false;
                $scope.ladda = {
                    season: false,
                    deleteSite: false,
                    share: false,
                    transfer: false
                };
   
               
                $scope.addUser = {
                    email: "",
                    roleViewOnly: false,
                    roleModify: false,
                    roleControlRT: false,
                    roleAdmin: true
                }
                $scope.userEmailTransfer = { address: "" };
                $scope.emailExistTransfer = true;
                $scope.userEmailShare;
                $scope.emailExistShare = true;
                //**********************************************************************************
                $scope.getSessons = function (siteID) {
                    siteProxy.getSessonList(siteID)
                                      .success(function (data) {
                                          $scope.newSeasson = {
                                              name: "",
                                              startDate: "",
                                              endDate: "",
                                              isAutoUpdate: false,
                                              sessionID: -1,
                                              isDelete: false
                                          }
                                          $scope.SiteSeassonList = data.body;
                                          pharseFirstSeassonDates($scope.SiteSeassonList);

                                      });
                }
                //**********************************************************************************
                function pharseFirstSeassonDates(SiteSeassonList) {
                    for (var i = 0; i < SiteSeassonList.length; i++) {
                        if (SiteSeassonList[i].startDate) {
                            SiteSeassonList[i].startDateStr = $filter('date')(SiteSeassonList[i].startDate, 'longDate');
                        }
                        if (SiteSeassonList[i].endDate) {
                            SiteSeassonList[i].endDateStr = $filter('date')(SiteSeassonList[i].endDate, 'longDate');
                        }
                    }
                }
                $scope.saveLastDateObject = function (obj) {
                    $scope.lastObj = jQuery.extend(true, {}, obj);
                }
                //***************************************************************************************************************
                $scope.dateValidateAndPharse = function (obj , index , type) {

                    if (type == 'start') {
                        if (startDateValidate(obj, index, $scope.SiteSeassonList)) {
                            pharseDate(obj, type);
                        } else {
                            alert('Start Date Error');
                            for (var a in $scope.lastObj) {
                                obj[a] = $scope.lastObj[a];
                            }
                            //obj = $scope.lastObj;
                        }
                    }
                    if (type == 'end') {
                        if (endDateValidate(obj)) {
                            pharseDate(obj, type);
                        } else {
                            alert('End Date Error');
                            obj = $scope.lastObj;
                        }
                    }
                    
                }
                //*************************************************************************
                function startDateValidate(obj, index , seassonList) {
                    if (index > 0) {
                        while (index > 0) {
                            if (obj.startDateStr < seassonList[index-1].endDate) {
                                return false;
                                
                            }
                            index--;
                        }
                    } else {
                        return true;
                    }
                    return true;
                }
                //*********************************************************************
                function endDateValidate(obj) {
                    if (obj.startDate > obj.endDateStr) {
                        return false;
                    }
                    return true;
                }

                //*************************************************************************************
                function pharseDate(obj , type) {
                    if(type=='start'){
                        obj.startDate = obj.startDateStr;  
                        obj.startDateStr = $filter('date')(obj.startDate, 'longDate');
                    }
                    if (type == 'end') {
                        obj.endDate = obj.endDateStr;
                        obj.endDateStr = $filter('date')(obj.endDate, 'longDate');
                    }
                  
                }
                //**********************************************************************************
                $scope.getOneSesson = function (sessonID) {
                    siteProxy.getOneSesson($scope.siteId, sessonID)
                                      .success(function (data) {
                                          $scope.SeassonModalTable = data;
                                          $scope.daySettingConnector.CallbackDown($scope.SeassonModalTable);
                                      });
                }
                //***********************************************************
                $scope.daySettingConnector.SetCallbackUp(function (data) {
                
                    $('#specificSeasson').modal('hide');

                });
                //************************************************************
                $scope.saveSessons = function () {
                    $scope.ladda.season = true;
                    if (($scope.newSeasson.name != '') && ($scope.newSeasson.startDate != '') && ($scope.newSeasson.endDate != '')) {
                        $scope.SiteSeassonList.push($scope.newSeasson);
                    }
                    siteProxy.saveSessonList($scope.siteId, $scope.SiteSeassonList)
                    
                                      .success(function (data) {
                                          $scope.getSessons($scope.siteId);
                                          
                                          $scope.ladda.season = false;
                                     
                                      });
                }
                //******************************************************************************
                $scope.sharingData = user.getSharingData().sharingData;
                ///**************************************************GetAllProjects**************************************************************
                $scope.GetAllProjects = function () {
                projectProxy.GetProjects(1, "", 10)
                                .success(function (data) {

                                    $scope.projectsList = data.projects;
                                    $scope.choosenProjectName = $scope.projectsList[0].name;
                                    $scope.getChoosenProject($scope.projectsList[0].projectID, $scope.choosenProjectName);
                                    fixLoadingOff();

                                });

                }
                ///*************************************filterSearch***************************************************************************
                $scope.filterSearch = function (txt) {
                    

                }
                ///**************************************************getChoosenProject**************************************************************
                $scope.getChoosenProject = function (projectId, projectName) {
                    $scope.choosenProjectId = projectId;
                    $scope.choosenProjectName = projectName;
                }
                ///****************************addSeassonRow************************************************************************************
                $scope.addNewSeasson = function () {
                    
                }
                ///****************************saveAndAdd************************************************************************************
                $scope.saveAndAdd = function (bool) {
                    var x = angular.copy($scope.extraSeasson);
                    if (bool == true) {
                        $scope.isValid = true;
                        //not valid, not add it but send data to services
                     
                    }
                    if (bool == false) {
                        // valid ,add it send data to services
                        $scope.isValid = false;

                        $scope.SiteSeassonList.SSL.push(x);
                      
                        $scope.extraSeasson.SeassonName = "";
                        $scope.extraSeasson.StartDate = "";
                        $scope.extraSeasson.EndDate = "";
                        $scope.extraSeasson.AutoUpdate = "";
                        $scope.extraSeasson.Weekly = "";
                    }
                  

                }
                ///***************************saveSeassonWeekly*************************************************************************************
                $scope.saveSeassonWeekly = function (func) {
                    func();
                }
                //*****************************************************************************
                $scope.GetAllProjects();
                //****************************************************************************
               
                //************************************************functions*******************
                //*************************************************getSharingList****************
                $scope.getSharingList = function (projectId) {
                    siteProxy.getSharingList(projectId)
                                       .success(function (data) {
                                           $scope.usersList = data.body;
                                       });

                }
                //*****************************************************transferProject(Outer)****************
                $scope.getTransferStatus = function (projectId) {
                    siteProxy.getTransferStatus(projectId)
                                       .success(function (data) {
                                           $scope.transferStatus = data.body;

                                       });
                }
                //*****************************************************transferProject(Outer)****************
                $scope.transferProject = function (projectId) {

                    $scope.ladda.transfer = true;
                    siteProxy.transferProject(projectId, $scope.userEmailTransfer.address)
                                  .success(function (data) {
                                      if (!data.body) {
                                          var msgNum = data.messages[0].code;
                                          toastr.error($filter('translate')(msgNum));

                                      }
                                      $scope.ladda.transfer = false;
                                      $scope.transferObj = data.body;
                                      $scope.ladda.transfer = false;
                                      $scope.transferStatus = data.body;
                                  }).error(function (data, status, headers, config) {

                                  });

                }
                //*************************************************cancelTransfer(Outer)****************
                $scope.cancelTransfer = function () {
                    siteProxy.cancelTransfer($scope.siteId)
                                       .success(function (data) {
                                         
                                           $scope.transferStatus.transferStatus = 0;
                                       });

                }
                //*************************************************cancelTransfer(Outer)****************
                $scope.deleteUser = function (userId) {
                    siteProxy.deleteUser($scope.siteId, userId)
                                         .success(function (data) {
                                             if (data.body) {
                                                 for (var i = 0 ; i < $scope.usersList.length; i++) {
                                                     if ($scope.usersList[i].linkedUserID == userId) {
                                                         $scope.usersList.splice(i, 1);
                                                     }
                                                 }
                                             } else {
                                                 toastr.error($filter('translate')('toastrErrMsgSave'));
                                             }
                                         }).error(function (data) {
                                             toastr.error($filter('translate')('toastrErrMsgSave'));
                                         });

                }
                //*************************************************shareProject(Outer)****************
                $scope.shareProject = function () {


                    if ($scope.shareForm.$valid) {
                        $scope.ladda.share = true;
                        //send to server
                        $scope.ladda.share = false;
                        $scope.emailValidationShare = false;
                    } else {
                        $scope.emailValidationShare = true;
                    }
                }
                //**************************************************************************************
                $scope.localTransfer = function () {
                    siteProxy.localTransfer($scope.choosenProjectId, $scope.siteId)
                                      .success(function (data) {
                                         
                                      })
                                     .error(function (data) {
                                         toastr.error($filter('translate')(data));
                                     });
                }
                //*************************************************cancelTransfer(Outer)****************
                $scope.sendShareUser = function () {
                    if ($scope.addUser.email.length > 0) {
                        var temp = $scope.usersList.slice(0);
                        temp.push($scope.addUser);
                        siteProxy.sendShareUser($scope.siteId, temp)
                            .success(function (data) {
                                $scope.addUser.email = "";
                                if (!data.body) {
                                    var msgNum = data.messages[0].code;
                                    toastr.error($filter('translate')(msgNum));

                                } else {
                                    $scope.usersList = data.body;
                                }
                            })
                           .error(function (data) {
                            });
                    } else {
                        siteProxy.sendShareUser($scope.siteId, $scope.usersList)
                           .success(function (data) {
                               if ($scope.addUser.email.length > 1) {
                                   $scope.addUser.email = "";
                               }
                           })
                            .error(function (data) {
                                $scope.addUser.email = "";
                            });
                    }
                }
            }],
            link: function (scope, element, attrs, ngModel) {
                if (!ngModel) return; // do nothing if no ng-model
                ngModel.$render = function () {

                    scope.siteId = ngModel.$viewValue;
                    fixLoadingOff();
                    scope.getSharingList(scope.siteId);
                    scope.getTransferStatus(scope.siteId);
                    scope.getSessons(scope.siteId)
                  


                };

            }




        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);








(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site.stats')
        .directive('alertLogDirective', alertLogDirectiveFactory);
    /********************************************************************AlertsLogDirectiveFactory****************************************************************************************************/
    function alertLogDirectiveFactory() {



        return {
            restrict: 'EA',
            require: '?ngModel',
            scope:{
            },
            templateUrl: 'app/modules/module.site/module.stats/alertsLog.html',
            controller: ['$scope', 'statsProxy', '$filter', 'translate', 'directiveComm', function ($scope, statsProxy, $filter, translate, directiveComm) {
                //************************************************Attributs*******************
                var PageSize = 10;
                $scope.AlertsConnector = directiveComm.CreateConnector();
                $scope.CostomDate = {
                    'startUnix': '',
                    'endUnix': '',
                    'startStr': '',
                    'endStr': ''
                };
                var date = {
                    'startUnix': '',
                    'endUnix': ''
                };
                $scope.ladda = {
                    "alertLoad": false,
                    "filter": false,
                    "csv": false
                };
                //************************************************functions*******************
                //***********************UnixTime(Outer)****************
                $scope.UnixTime = function (local, param) {
                    var unixInt = parseInt(local);
                    var str = $filter('date')(local, 'mediumDate');
                    if (param == 0) {
                        $scope.CostomDate.startStr = str;
                        $scope.CostomDate.startUnix = translate.fullDateStringToUnixServer(str, "00:00")
                    } else {
                        $scope.CostomDate.endStr = str;
                        $scope.CostomDate.endUnix = translate.fullDateStringToUnixServer(str, "00:00")
                    }
                }
                //***********************AlertsConnector.SetCallbackUp(Outer)****************
                $scope.AlertsConnector.SetCallbackUp(function (pageNumber) {  //
                    $scope.getAlertsLog(pageNumber, date);
                });

                //***********************GetTopAlertsLog(Outer)****************
                $scope.GetTopAlertsLog = function (id, type) {
                    $scope.logsBy = 'Top';
                    $scope.pagerFlag = false;
                    switch (type) {
                        case 0:
                            statsProxy.GetTopAlertsLogSite(id, PageSize)

                              .success(function (data) {
                                  $scope.AlertsLog = data.body;
                                  $scope.ladda.alertLoad = false;
                              });
                            break;
                        case 1:
                            statsProxy.GetTopAlertsLogDevice(id)

                              .success(function (data) {
                                  $scope.AlertsLog = data.body;
                                  $scope.ladda.alertLoad = false;
                              });
                            break;
                    }
                    fixLoadingOff();

                }
                //***********************GetDates(Outer)****************
                $scope.GetDates = function (search) {

                    $scope.ladda.alertLoad = true;
                    switch (search) { // return start and end date
                        case 'Top':
                            $scope.logsBy = 'Top';
                            $scope.costom = false;
                            $scope.GetTopAlertsLog($scope.id, $scope.type);
                            break;
                        case 'lastYear':
                            $scope.logsBy = 'lastYear';
                            $scope.costom = false;
                            date = translate.getLastYear();
                            $scope.getAlertsLog(1, date);
                            break;
                        case 'lastMonth':
                            $scope.logsBy = 'lastMonth';
                            $scope.costom = false;
                            date = translate.getLastMonth();
                            $scope.getAlertsLog(1, date);
                            break;
                        case 'lastWeek':
                            $scope.logsBy = 'lastWeek';
                            $scope.costom = false;
                            date = translate.getLastWeek();
                            $scope.getAlertsLog(1, date);
                            break;
                        case 'Costom':
                            $scope.logsBy = 'Costom';
                            $scope.costom = true;
                            $scope.ladda.alertLoad = false;
                            break;
                    }



                }

                //***********************filter(Outer)****************
                $scope.filter = function () {
                    $scope.ladda.filter = true;
                    $scope.getAlertsLog(1, $scope.CostomDate);
                }

                //***********************getAlertsLog(Outer)****************
                $scope.getAlertsLog = function (currentPage, date) {

                    switch ($scope.type) {
                        case 0:
                            $scope.currentPage = currentPage;
                            statsProxy.getAlertsLogSite($scope.id, $scope.type, date, $scope.currentPage)
                              .success(function (data) {

                                  $scope.pagerFlag = true;
                                  $scope.AlertsLog = data.body;
                                  $scope.AlertsConnector.CallbackDown(currentPage, PageSize, data.body.metadata.totalItems);
                                  $scope.ladda.alertLoad = false;
                                  $scope.ladda.filter = false;
                              });
                            break;
                        case 1:
                            $scope.ladda.alertLoad = false;
                            $scope.ladda.filter = false;
                            break;
                    }






                }

            }],
            //**********************************************************Link****************
            link: function (scope, element, attrs, ngModel) {
                if (!ngModel) return;
                ngModel.$render = function () {
                    if (attrs.type == 'site') {

                        scope.type = 0; //logs for site
                    }
                    if (attrs.type == 'device') {

                        scope.type = 1; //log for device
                    }
                    scope.id = ngModel.$viewValue;
                    scope.GetTopAlertsLog(scope.id, scope.type);
                };


            }




        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);








(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    chartsDirectiveFactory.$inject = ['$log'];
    angular.module('module.site.stats')
        .directive('chartsDirective', chartsDirectiveFactory);
    /*********************************************************************************************************************************************************************/
    function chartsDirectiveFactory($log) {



        return {
            restrict: 'EA',
            require: '?ngModel',
            templateUrl: 'app/modules/module.site/module.stats/charts.html',

            controller: ['$scope', 'statsProxy', '$filter', 'translate', function ($scope, statsProxy, $filter, translate) {
             
                $scope.costom = false;
                $scope.radioType = 'Duration';
                $scope.chartsBy = 'lastWeek';

                //***********************GetDates(Outer)****************
                $scope.GetDates = function (search) {
                    var date;
                    
                    switch (search) { // return start and end date
                      
                        case 'lastYear':
                            $scope.chartsBy = 'G_LAST_YEAR';
                            $scope.costom = false;
                            date = translate.getLastYear();
                            $scope.GetStackDetails(date);
                            break;
                        case 'lastMonth':
                            $scope.chartsBy = 'G_LAST_MONTH';
                            $scope.costom = false;
                            date = translate.getLastMonth();
                            $scope.GetStackDetails(date);
                            break;
                        case 'lastWeek':
                            $scope.chartsBy = 'G_LAST_WEEK';
                            $scope.costom = false;
                            date = translate.getLastWeek();
                            $scope.GetStackDetails(date);
                            break;
                        case 'Costom':
                            $scope.chartsBy = 'G_CUSTOM';
                            $scope.costom = true;
                            $scope.GetStackDetails(date);
                            break;
                    }



                }

                //*********************************************************

                $scope.radioCange = function (type) {
                    $scope.radioType = type;
                    organize_data($scope.stackDetails);

                }

                function organize_data(data) {


                    $scope.stackDetails = data;
                    $scope.Sum = {
                        savingDuration: 0,
                        savingQuantity: 0,
                        usedDuration: 0,
                        usedQuantity: 0,
                        type: $scope.radioType


                    };

                    for (var i = 0; i < data.length; i++) {
                         $scope.Sum.savingDuration =  $scope.Sum.savingDuration + parseInt(data[i].savingDuration);
                         $scope.Sum.savingQuantity =  $scope.Sum.savingQuantity + parseInt(data[i].savingQuantity);
                         $scope.Sum.usedDuration =  $scope.Sum.usedDuration + parseInt(data[i].usedDuration);
                         $scope.Sum.usedQuantity =  $scope.Sum.usedQuantity + parseInt(data[i].usedQuantity);
                    }

                    $scope.pieDetails = $scope.Sum;

                    $scope.stackBarMatrix = new Array($scope.stackDetails.length);
                    for (var i = 0; i < $scope.stackDetails.length; i++) {
                        $scope.stackBarMatrix[i] = new Array(3);

                        if ($scope.radioType == "Duration") {
                            $scope.stackBarMatrix[i][0] = $filter('date')($scope.stackDetails[i].date, 'mediumDate');
                            $scope.stackBarMatrix[i][1] = parseInt($scope.stackDetails[i].usedDuration);
                            $scope.stackBarMatrix[i][2] = parseInt($scope.stackDetails[i].savingDuration);
                        } else {
                            $scope.stackBarMatrix[i][0] = $filter('date')($scope.stackDetails[i].date, 'mediumDate');
                            $scope.stackBarMatrix[i][1] = parseInt($scope.stackDetails[i].usedQuantity);
                            $scope.stackBarMatrix[i][2] = parseInt($scope.stackDetails[i].savingQuantity);
                        }


                        $scope.stackBarMatrix[i][3] = '';

                    }
                    var first = ['Genre', 'used', 'saving', { role: 'annotation' }];
                    $scope.stackBarMatrix.unshift(first);
                    $scope.pieObj.changeData($scope.Sum);
                    $scope.stackBarObj.changeData($scope.stackBarMatrix);
                }


                $scope.GetStackDetails = function (date) {
                    statsProxy.GetStackDetails($scope.siteId, date.startUnix, date.endUnix)
                   .success(function (data) {
                       organize_data(data);
                       fixLoadingOff();
                   });

                }

              
            }],
            link: function (scope, element, attrs, ngModel) {

                scope.pieObj = {
                    data: null,
                    options: null,
                    changeOptionsCallback: null,
                    changeOptions: function (_options) {
                        this.options = _options;

                        if (this.changeOptionsCallback) {
                            this.changeOptionsCallback(_options);
                        }
                    },
                    changeData: function (_data) {
                        this.data = _data;

                        if (this.changeDataCallback) {
                            this.changeDataCallback(_data);
                        }
                    },
                    changeDataCallback: null
                };

                scope.stackBarObj = {
                    data: null,
                    options: null,
                    changeOptionsCallback: null,
                    changeOptions: function (_options) {
                        this.options = _options;

                        if (this.changeOptionsCallback) {
                            this.changeOptionsCallback(_options);
                        }
                    },
                    changeData: function (_data) {
                        this.data = _data;

                        if (this.changeDataCallback) {
                            this.changeDataCallback(_data);
                        }
                    },
                    changeDataCallback: null
                };


                if (!ngModel) return;
                ngModel.$render = function () {
                    
                    scope.siteId = ngModel.$viewValue.toString();
                    scope.GetDates('lastWeek');

                };


            }




        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);








(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site.stats')
        .directive('pieCharts', pieChartsFactory);
    /*********************************************************************************************************************************************************************/
    function pieChartsFactory() {


        return {
            restrict: 'EA',
            scope: {
                obj: '='
            },

            link: function (scope, element, attrs, ngModel) {

               
                //scope.obj.changeOptionsCallback = function (options) {
                //    scope.options = options;
                //    drawChart();
                //};

                scope.obj.changeDataCallback = function (data) {
                    scope.data = data;                    
                    
                    drawChart();
                };


                drawChart();

                google.load("visualization", "1", { packages: ["corechart"], "callback": createChart });
                var chart;
               // var options;
                function createChart() {
                    chart = new google.visualization.PieChart(element[0]);
                    drawChart();
                }
                function drawChart() {

                    if (!scope.obj.data || !chart)
                        return;

                    if (scope.obj.data.type == 'Duration') {
                        var data = google.visualization.arrayToDataTable([
                                             ['Task', 'Hours per Day'],
                                             ['Used', scope.obj.data.usedDuration],
                                             ['Saving', scope.obj.data.savingDuration]

                        ]);
                    } else {
                        var data = google.visualization.arrayToDataTable([
                                            ['Task', 'Hours per Day'],
                                            ['Used', scope.obj.data.usedQuantity],
                                            ['Saving', scope.obj.data.savingQuantity]

                        ]);
                    }
                   

                    var options = {
                        title: '',
                        backgroundColor: 'transparent',
                        colors: ['#4086AA', '#91C3DC'],
                        is3D: true,
                    };

                   
                    chart.draw(data, options);

                    //scope.$on('pieDetails', function (event, data1) {
                    //    scope.obj = data1;
                    //    chart.draw(data, options);

                    //});
                }

               






            }
        };
       

        
    }
    /*******************************************************************************************************************************************************************************/

})(angular);








(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site.stats')
        .directive('stackedBarCharts', stackedBarChartsFactory);
    /*********************************************************************************************************************************************************************/
    function stackedBarChartsFactory() {


        return {
            restrict: 'EA',
            scope: {
                obj1: '='
            },

            link: function (scope, element, attrs, ngModel) {

               
                scope.obj1.changeOptionsCallback = function (options) {
                    scope.options = options;
                    drawChart();
                };

                scope.obj1.changeDataCallback = function (data) {
                    scope.data = data;

                    drawChart();
                };


                drawChart();

                google.load("visualization", "1", { packages: ["corechart", 'bar'], "callback": createChart });
                var chart;
                // var options;
                function createChart() {
                    chart = new google.visualization.BarChart(element[0]);
                    drawChart();
                }
                function drawChart() {

                    if (!scope.obj1.data || !chart)
                        return;

                 
                    var data = google.visualization.arrayToDataTable(scope.obj1.data);

                    var options = {
                        width: 600,
                        height: 400,
                        backgroundColor: 'transparent',
                        colors: ['#4086AA', '#91C3DC'],
                        legend: { position: 'top', maxLines: 3 },
                        bar: { groupWidth: '75%' },
                        isStacked: true
                    };

                    chart.draw(data, options);

                  
                }








            }
        };



    }
    /*******************************************************************************************************************************************************************************/

})(angular);








(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    generalFactory.$inject = ['$log'];
    angular.module('module.site.stats')
        .directive('general', generalFactory);
    /********************************************************************GeneralLogDirectiveFactory****************************************************************************************************/
    function generalFactory($log) {



        return {
            restrict: 'EA',
            require: '?ngModel',
            scope: {

            },
            templateUrl: 'app/modules/module.site/module.stats/statsGeneral.html',
            controller: ['$scope', 'statsProxy', '$filter', 'translate', 'directiveComm', function ($scope, statsProxy, $filter, translate, directiveComm) {
                //************************************************Attributs*******************
                var PageSize = 10;
                $scope.GeneralConnector = directiveComm.CreateConnector();
                $scope.CostomDate = {
                    'startUnix': '',
                    'endUnix': '',
                    'startStr': '',
                    'endStr': ''
                };
                var date = {
                    'startUnix': '',
                    'endUnix': ''
                };
                $scope.ladda = {
                    "generalLoad": false,
                    "filter": false,
                    "csv": false  
                };
                //************************************************functions*******************
                //***********************UnixTime(Outer)****************
                $scope.UnixTime = function (local , param) {
                    var unixInt = parseInt(local);
                    var str = $filter('date')(local, 'mediumDate');
                    if (param == 0) {
                        $scope.CostomDate.startStr = str;
                        $scope.CostomDate.startUnix = translate.fullDateStringToUnixServer(str, "00:00")
                    } else {
                        $scope.CostomDate.endStr = str;
                        $scope.CostomDate.endUnix = translate.fullDateStringToUnixServer(str, "00:00")
                    }
                }
                //***********************GeneralConnector.SetCallbackUp(Outer)****************
                $scope.GeneralConnector.SetCallbackUp(function (pageNumber) {  //

                    $scope.getGeneralLog(pageNumber, date);

                });

                //***********************GetTopGeneralLog(Outer)****************
                $scope.GetTopGeneralLog = function (id, type) {
                    $scope.logsBy = 'Top';
                    $scope.pagerFlag = false;
                    switch (type) {
                        case 0:
                            statsProxy.GetTopGeneralLogSite(id, PageSize)

                              .success(function (data) {
                                  $scope.GeneralLog = data.body;
                                  $scope.ladda.generalLoad = false;
                              });
                            break;
                        case 1:
                            statsProxy.GetTopGeneralLogDevice(id)

                              .success(function (data) {
                                  $scope.GeneralLog = data.body;
                                  $scope.ladda.generalLoad = false;

                              });
                            break;
                    }

                    fixLoadingOff();
                }
                //***********************GetDates(Outer)****************
                $scope.GetDates = function (search) {
                    $scope.ladda.generalLoad = true;

                    switch (search) { // return start and end date
                        case 'Top':
                            $scope.logsBy = 'Top';
                            $scope.costom = false;
                            $scope.GetTopGeneralLog($scope.id, $scope.type);
                            break;
                        case 'lastYear':
                            $scope.logsBy = 'lastYear';
                            $scope.costom = false;
                            date = translate.getLastYear();
                            $scope.getGeneralLog(1, date);
                            break;
                        case 'lastMonth':
                            $scope.logsBy = 'lastMonth';
                            $scope.costom = false;
                            date = translate.getLastMonth();
                            $scope.getGeneralLog(1, date);
                            break;
                        case 'lastWeek':
                            $scope.logsBy = 'lastWeek';
                            $scope.costom = false;
                            date = translate.getLastWeek();
                            $scope.getGeneralLog(1, date);
                            break;
                        case 'Costom':
                            $scope.logsBy = 'Costom';
                            $scope.costom = true;
                            $scope.ladda.generalLoad = false;
                            break;
                    }



                }

                //***********************filter(Outer)****************
                $scope.filter = function () {
                    $scope.ladda.filter = true;
                    $scope.getGeneralLog(1, $scope.CostomDate);
                }


                //***********************getGeneralLog(Outer)****************
                $scope.getGeneralLog = function (currentPage, date) {

                    switch ($scope.type) {
                        case 0:
                            $scope.currentPage = currentPage;
                            statsProxy.getGeneralLogSite($scope.id, $scope.type, date, $scope.currentPage)
                              .success(function (data) {

                                  $scope.pagerFlag = true;
                                  $scope.GeneralLog = data.body;
                                  $scope.GeneralConnector.CallbackDown(currentPage, PageSize, data.body.metadata.totalItems);
                                  $scope.ladda.generalLoad = false;
                                  $scope.ladda.filter = false;
                              });
                            break;
                        case 1:
                            $scope.ladda.generalLoad = false;
                            $scope.ladda.filter = false;
                            break;
                    }






                }

                $scope.getLinkData = function (sn ,  connectionId) {
                  
                    switch ($scope.type) {
                        case 0:
                            statsProxy.getLinkData($scope.id,sn, connectionId)

                              .success(function (data) {
                                  $scope.linkLog = data.body;


                              });
                            break;
                        case 1:
                           
                            break;
                    }


                }




            }],
            link: function (scope, element, attrs, ngModel) {
                if (!ngModel) return;
                ngModel.$render = function () {
                    if (attrs.type == 'site') {

                        scope.type = 0; //logs for site
                    }
                    if (attrs.type == 'device') {

                        scope.type = 1; //log for device
                    }
                    scope.id = ngModel.$viewValue;
                    scope.GetTopGeneralLog(scope.id, scope.type);
                };


            }




        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);








(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.site.stats')
        .provider('stateService', stateService);
    function stateService() {

        var date = {
            'startUnix': '',
            'endUnix': ''
        }
        //***********************getLastYear(Outer)****************
        function getLastYear() {
            var GmtAbs = localTime.getTimezoneOffset() * 60 * 1000;
            var localTime = new Date();
            var lastYear = localTime.setFullYear(localTime.getFullYear() - 1)
            date.end = localTime.getTime() - GmtAbs;
            date.start = lastYear.getTime() - GmtAbs;
            return date;
        }
        //***********************getLastMonth(Outer)****************
        function getLastMonth () {
            var GmtAbs = localTime.getTimezoneOffset() * 60 * 1000;
            var localTime = new Date();
            var lastMonth = localTime.setMonth(localTime.getMonth() - 1)
            date.end = localTime.getTime() - GmtAbs;
            date.start = lastYear.getTime() - GmtAbs;
            return date;
        //***********************getLastWeek(Outer)****************   
        }
        function getLastWeek() {
            var GmtAbs = localTime.getTimezoneOffset() * 60 * 1000;
            var localTime = new Date();
            var lastWeek = new Date(today.getFullYear(), today.getMonth(), today.getDate() - 7);
            date.end = localTime.getTime() - GmtAbs;
            date.start = lastWeek.getTime() - GmtAbs;
            return date;
        }
        //***********************strDateToUnix(Outer)****************   
        function strDateToUnix(dateStr) {
            var x = new Date(dateStr.start);
            date.start = x.getTime();
            var x = new Date(dateStr.end);
            date.end = x.getTime();
            return date;
        }
        return {
            $get: function () {
                //interface
                return {
                   
                    getLastYear: getLastYear,
                    getLastMonth: getLastMonth,
                    getLastWeek: getLastWeek
                 
                };
            }
        }
    }
})(angular);







(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    usageLogDirectiveFactory.$inject = ['$log'];
    angular.module('module.site.stats')
        .directive('usageLogDirective', usageLogDirectiveFactory);
    /********************************************************************usageLogDirectiveFactory****************************************************************************************************/
    function usageLogDirectiveFactory($log) {



        return {
            restrict: 'EA',
            require: '?ngModel',
            scope: {},
            templateUrl: 'app/modules/module.site/module.stats/usageLog.html',
            controller: ['$scope', 'statsProxy', '$filter', 'translate', 'directiveComm', function ($scope, statsProxy, $filter, translate, directiveComm) {
              //************************************************Attributs*******************
              var PageSize = 10;
              $scope.usageConnector = directiveComm.CreateConnector();
              $scope.CostomDate = {
                    'startUnix': '',
                    'endUnix': '',
                    'startStr': '',
                    'endStr': ''
                };
                var date = {
                      'startUnix': '',
                      'endUnix': ''
                };
                $scope.ladda = {
                    "usageLoad": false,
                    "filter": false,
                    "csv": false  
                };
                //************************************************functions*******************
                //***********************UnixTime(Outer)****************
                $scope.UnixTime = function (local , param) {
                    var unixInt = parseInt(local);
                    var str = $filter('date')(local, 'mediumDate');
                    if (param == 0) {
                        $scope.CostomDate.startStr = str;
                        $scope.CostomDate.startUnix = translate.fullDateStringToUnixServer(str, "00:00")
                    } else {
                        $scope.CostomDate.endStr = str;
                        $scope.CostomDate.endUnix = translate.fullDateStringToUnixServer(str, "00:00")
                    }
                }
                //***********************usageConnector.SetCallbackUp(Outer)****************
                $scope.usageConnector.SetCallbackUp(function (pageNumber) { 

                    $scope.getUsageLog(pageNumber, date);

                });
                //***********************GetTopUsageLog(Outer)****************
                $scope.GetTopUsageLog = function (id, type) {
                    $scope.logsBy = 'Top';
                    $scope.pagerFlag = false;
                    switch (type) {
                        case 0:
                            statsProxy.GetTopUsageLogSite(id, PageSize)
                              .success(function (data) {
                                  $scope.usageLog = data.body;
                                  $scope.ladda.usageLoad = false;
                       });
                            break;
                        case 1:
                            statsProxy.GetTopUsageLogDevice(id)
                              .success(function (data) {
                                  $scope.usageLog = data.body;
                                  $scope.ladda.usageLoad = false;
                              });
                            break;
                    }
                    fixLoadingOff();
                }
                //***********************GetDates(Outer)****************
                $scope.GetDates = function (search) {

                    $scope.ladda.usageLoad = true;
                    switch (search) { // return start and end date
                        case 'Top':
                            $scope.logsBy = 'Top';
                            $scope.costom = false;
                            $scope.GetTopUsageLog($scope.id, $scope.type);
                            break;
                        case 'lastYear':
                            $scope.logsBy = 'lastYear';
                            $scope.costom = false;
                            date = translate.getLastYear();
                            $scope.getUsageLog(1, date);
                            break;
                        case 'lastMonth':
                            $scope.logsBy = 'lastMonth';
                            $scope.costom = false;
                            date = translate.getLastMonth();
                            $scope.getUsageLog(1, date);
                            break;
                        case 'lastWeek':
                            $scope.logsBy = 'lastWeek';
                            $scope.costom = false;
                            date = translate.getLastWeek();
                            $scope.getUsageLog(1, date);
                            break;
                        case 'Costom':
                            $scope.logsBy = 'Costom';
                            $scope.costom = true;
                            $scope.ladda.usageLoad = false;
                            break;
                    }

                  

                }
                //***********************filter(Outer)****************
                $scope.filter = function () {
                    $scope.ladda.filter = true;
                    $scope.getUsageLog(1, $scope.CostomDate);
                    
                }
                //***********************getUsageLog(Outer)****************
                $scope.getUsageLog = function (currentPage, date) {

                    switch ($scope.type) {
                        case 0:
                            $scope.currentPage = currentPage;
                            statsProxy.getUsageLogSite($scope.id, $scope.type, date, $scope.currentPage)
                              .success(function (data) {

                                  $scope.pagerFlag = true;
                                  $scope.usageLog = data.body;
                                  $scope.usageConnector.CallbackDown(currentPage, PageSize, data.body.metadata.totalItems);
                                  $scope.ladda.usageLoad = false;
                                  $scope.ladda.filter = false;
                              });
                            break;
                        case 1:
                            
                            break;
                    }

                }

            }],
            //**********************************************************Link****************
            link: function (scope, element, attrs, ngModel) {
                if (!ngModel) return;
                ngModel.$render = function () {
                    if (attrs.type == 'site') {
                        
                        scope.type = 0; //logs for site
                    }
                    if (attrs.type == 'device') {
                   
                        scope.type = 1; //log for device
                    }
                    scope.id = ngModel.$viewValue;
                    scope.GetTopUsageLog(scope.id, scope.type);
                };


            }




        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);







(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.GSI.Device')
        .directive('alertsSettings', alertsSettingsFactory);



    function alertsSettingsFactory() {
        return {
            restrict: 'EA',

            templateUrl: 'app/modules.devices/GSI.Device/settings/alert/alertsSettings.html',

            controller: ['$scope', function ($scope) {
            //*********************************************************************************************
                $scope.alerts = {
                    isSendEmail: true,
                    table: [
                        { type: "Low Flow", stopStation: false, terminateProgram: false, openNext: true, forceCom: false },
                        { type: "hight Flow", stopStation: false, terminateProgram: false, openNext: true, forceCom: false },
                        { type: "No Waret Flow", stopStation: false, terminateProgram: false, openNext: true, forceCom: false },
                        { type: "Unexpected Flow Start", stopStation: false, terminateProgram: false, openNext: true, forceCom: false },
                        { type: "Unexpected Flow End", stopStation: false, terminateProgram: false, openNext: true, forceCom: false },
                        { type: "Communication Alert", stopStation: false, terminateProgram: false, openNext: true, forceCom: false },
                    ],
                    stopStationIrrigation: true,
                    TerminateProgram:true,
                    allowFertilizing:true,
                    forceComm:true,
                }


             

            }],
            link: function (scope, element, attrs, ngModel) {



            }




        };

    }
})(angular);
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.GSI.Device')
        .directive('stationSettings', stationSettingsFactory);



    function stationSettingsFactory() {
        return {
            restrict: 'EA',

            templateUrl: 'app/modules.devices/GSI.Device/settings/station/stationSettings.html',

            controller: ['$scope', function ($scope) {
             
                //*********************************************************************************************
                $scope.stations = {
                    tableHead: [  { id: 1, name: "S1" }
                                , { id: 2, name: "S2" }
                                , { id: 3, name: "S3" }
                                , { id: 4, name: "S4" }
                                , { id: 5, name: "S5" }
                                , { id: 6, name: "S6" }
                                , { id: 7, name: "S7" }
                                , { id: 8, name: "S8" }
                                , { id: 9, name: "S9" }
                                , { id: 10, name: "S10" }
                                , { id: 11, name: "S11" }
                                , { id: 12, name: "S12" }
                                , { id: 13, name: "S13" }
                                , { id: 14, name: "S14" }
                                , { id: 15, name: "S15" }
                                , { id: 16, name: "S16" }
                                , { id: 17, name: "S17" }
                                , { id: 18, name: "S18" }
                                , { id: 19, name: "S19" }
                                , { id: 20, name: "S20" }
                                , { id: 21, name: "S21" }
                                , { id: 22, name: "S22" }
                                , { id: 23, name: "S23" }
                                , { id: 24, name: "S24" }
                           
                    ],
                    allStations: [
                        { value: "Active" }
                      , { }
                      , { }
                      , { des: "Copy value from last irrigation" }
                      , { des: "Higher Than", value: 30, units: "%" }
                      , { des: "For All Stations", value: 1, units: "Min" }
                      , { des: "Less Than", value: 27, units: "%" }
                      , { des: "For All Stations", value: 30, units: "Min" }
                      , { des: "For All Stations", value: 30, units: "Min" }
                      , {}
                      , {}
                    ],
                    tableRow: [
                        {
                            categorey: "Status",
                            list: [
                              { value: "Active" }, { value: "Off" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }, { value: "Active" }
                            ]
                        },
                        {
                            categorey: "Station Name",
                            list: [
                              { value: "S1" }, { value: "S2" }, { value: "S3" }, { value: "S4" }, { value: "S5" }, { value: "S6" }, { value: "S7" }, { value: "S8" }, { value: "S9" }, { value: "S10" }, { value: "S11" }, { value: "S12" }, { value: "S13" }, { value: "S14" }, { value: "S15" }, { value: "S16" }, { value: "S17" }, { value: "S18" }, { value: "S19" }, { value: "S20" }, { value: "S21" }, { value: "S22" }, { value: "S23" }, { value: "S24" }
                            ]
                        },
                         {
                             categorey: "Last Flow Rate",
                             list: [
                               { value: 180, unit: "m3/h" }, { value: 0, unit: "m3/h" }, { value: 0, unit: "m3/h" }, { value: 58, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 0, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }, { value: 705, unit: "i/h" }
                             ]
                         },
                        
                        
                         {
                             categorey: "set Nominimal Flow (m3/h)",
                             list: [
                               { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }
                             ]
                         }
                         ,
                         {
                             categorey: "High Flow Alert (%)",
                             list: [
                               { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }
                             ]
                         }
                         ,
                         {
                             categorey: "Delay Before Low Flow Alert (min)",
                             list: [
                               { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }
                             ]
                         }
                         ,
                         {
                             categorey: "Line Fill Time (min)",
                             list: [
                               { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }
                             ]
                         }
                         ,
                         {
                             categorey: "Area Size (m2)",
                             list: [
                               { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }
                             ]
                         }
                         ,
                         {
                             categorey: "Precipitation Rate (mm/hr)",
                             list: [
                               { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }, { value: 1 }
                             ]
                         }


                    ],
                    stopStationIrrigation: true,
                    TerminateProgram: true,
                    allowFertilizing: true,
                    forceComm: true,
                }




            }],
            link: function (scope, element, attrs, ngModel) {



            }




        };

    }
})(angular);

(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.GSI.Device')
        .directive('unitSettings', unitSettingsFactory);



    function unitSettingsFactory() {
        return {
            restrict: 'EA',

            templateUrl: 'app/modules.devices/GSI.Device/settings/unit/unitSettings.html',

            controller: ['$scope', function ($scope) {
                //*********************************************************************************************

                $scope.unitState = {
                    state:'Active'
                }

                $scope.generalSettings = {
                    
                    weekly: {
                        days: [{ num: 0, state: true }, { num: 1, state: false }, { num: 2, state: true }, { num: 3, state: true }, { num: 4, state: true }, { num: 5, state: true }, { num: 6, state: true }]
                    },
                    nonIrrigationDates: [{ date: 1452178120549 }, { date: 1452067381081 }],
                    rainSensor:true
                }

                $scope.waterMeter = {
                    useWaterMeter: true,
                    size: ["1 Liter", "10 Liter", "100 Liter", "1 m3", "10 m3"],
                    choosenSize: "1 Liter",
                    waitBefor: 20,
                    enableLeack: true,
                    pulseAlert:5
                }

                $scope.fertilizer = {
                    useFertilizer: true,
                    pumpType: "fertilizer",
                    rate: 6,
                    stroke: 2,
                    fertilizerAlert: true,
                    size: ["1 cc", "10 cc", "100 cc", "1 liter", "10 liter"],
                    choosenSize: "1 cc",
                    useCustomValue: false,
                    customValue: 3,
                    injectionM: "proportional",
                    noFertilizerFlowAlert: 180,
                    fertilizerLeakage: true,
                    numberOfPulse:20
                }
                $scope.season = {
                    start: 1452178120549,
                    end: 1452178120549,
                    budget: 0,
                    total: false,
                    season:false,
                    month:false,
                    messages:false,
                    unexpectedFlow:false,
                    powerControl:false
                    
                }
                $scope.advanced = {
                    mUnit: "metric",
                    mList: ["m2", "Dunam", "hectare"],
                    iList: ["ft2", "Acres"],
                    showMlist: true,
                    mCurrentType: "m2",
                    iCurrentType: "ft2",
                    mOpen: "station",
                    mOpenDelay:5,
                    mClose: "master",
                    mCloseDelay: 5,
                    pStationOverlapOrDelay: "overflap",
                    pStationOverlapOrDelaySecs:5

                    
                }
                //*********************************************************************************************
                $scope.advancedSetAreaUnit = function (m, s) {
                    if (m == 'metric') {
                        $scope.advanced.mCurrentType = s;
                    } else {
                        $scope.advanced.iCurrentType = s;
                    }
                }
                //*********************************************************************************************
                $scope.setAdvancedMeasurementUnit = function (m) {
                    if (m == 'metric') {
                        $scope.advanced.showMlist = true;
                    } else {
                        $scope.advanced.showMlist = false;
                    }

                }
                //********************************************************************************************
                $scope.waterMeterSetPulseSize = function (s) {
                    $scope.waterMeter.choosenSize = s;
                }
                //********************************************************************************************
                $scope.fertilizerSetPulseSize = function (s) {
                    $scope.fertilizer.choosenSize = s;
                }
                //*********************************************************************************************
                $scope.deleteNonIrrigationDates = function () {
                    $scope.generalSettings.nonIrrigationDates = [];
                }
                //*********************************************************************************************
                $scope.chooseNewDate = function (date) {
                    //check if date diffrent and than push to array
                    var obj = {
                        date: date
                    }
                    $scope.generalSettings.nonIrrigationDates.push(obj);
                }
                //**********************************************************************************************

            }],
            link: function (scope, element, attrs, ngModel) {



            }




        };

    }
})(angular);

(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module("module.XCI.zones")
        .directive('zoneOddEven', zoneOddEvenFactory);
    /********************************************************************************************************************************************************************/
    function zoneOddEvenFactory() {

        return {
            restrict: 'EA',
            require: '?ngModel',
            scope: {
                scheduleview: '=',
                comm: '='
            },
            templateUrl: 'app/modules.devices/XCI.Device/module.XCI.zone/zoneOddEven.html',
            controller: ['$scope', '$locale', 'translate', function ($scope, $locale, translate) {
                //********************************Attributes************************************
                $scope.locale = $locale;
                $scope.translate = translate;
                
                
                //**************************************************************************
                $scope.pharseTime = function (scheduleview) {
                    for (var i = 0; i < scheduleview.startTimes.length; i++) {
                        scheduleview.startTimes[i].durationStr = scheduleview.startTimes[i].duration / 60;
                    }
                   
                    $scope.startPage = true;
                }
                
                //***************************************************************************
                $scope.bodyValChange = function (tb) {
                    tb.duration = parseFloat(tb.durationStr) * 60;
                }
                //********************************sumRow************************************
                $scope.sumRow = function (index) {
                    $scope.sumAll = 0;
                    $scope.scheduleview.startTimes[index].sum =  parseInt($scope.scheduleview.startTimes[index].durationStr || 0) * 15;
                    for (var i = 0; i < $scope.scheduleview.startTimes.length; i++) {
                        $scope.sumAll = $scope.sumAll + $scope.scheduleview.startTimes[i].sum
                    }
                    return $scope.scheduleview.startTimes[index].sum;
                }
            }],
            link: function (scope, element, attrs, ngModel) {
                scope.type = attrs.page;
                if (!ngModel) return;
                ngModel.$render = function () {

                    scope.pharseTime(scope.scheduleview);
                };
            }
        };//return
    }
})(angular);



(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.XCI.zones')
        .directive('zonesCategories', zonesCategoriesFactory);
    /***********************************************************************************************************************************************************************/
    function zonesCategoriesFactory() {
        return {
            restrict: 'EA',
            templateUrl: 'app/modules.devices/XCI.Device/module.XCI.zone/zonesCategories.html',

            controller: ['$scope', 'zoneProxy', 'directiveComm', '$state', 'mainRouter', '$stateParams', '$filter', 'onlineProvider', 'deviceProxy', function ($scope, zoneProxy, directiveComm, $state, mainRouter, $stateParams, $filter, onlineProvider, deviceProxy) {
                //**************************************Attribute******************************
                const MAX_DIFF_ZONES_UPDATE = 20;
                var precent;
                var fill;
                $scope.param = 1;
                $scope.ladda = {
                    "flow": false,
                    "settings": false,
                    "schedule": false,
                    "acceptSeggestion": false,
                    "saveWizard": false,
                    "uploadFile":false
                }
                $scope.refreshTable = 0;
                $scope.deviceId = $stateParams.deviceId;
                $scope.zoneId = $stateParams.zoneId;
                $scope.scheduleConnector = directiveComm.CreateConnector();
                $scope.OddEvenConnector = directiveComm.CreateConnector();
                $scope.adviserConnector = directiveComm.CreateConnector();
                var zoneEvent = (4000 + parseInt($scope.zoneId)-1).toString();
                var OnlineEvents = [zoneEvent];
                //**************************************Functions******************************
                function parseSecondsToStringDate(sec) {
                    var seconds = Math.floor(sec % 60).toString();
                    var minutes = Math.floor((sec / 60) % 60).toString();
                    var hours = Math.floor((sec / (60 * 60)) % 24).toString();
                    if (seconds.length == 1) {
                        seconds = '0' + seconds;
                    }
                    if (minutes.length == 1) {
                        minutes = '0' + minutes;
                    }
                    if (hours.length == 1) {
                        hours = '0' + hours;
                    }
                    return hours + ':' + minutes + ':' + seconds
                }
                //****************************************************************************
                function onlineCBfuncZonePage(data) {
                    calcZoneTimeLeft(data);
                }
                //**************************************************************************************
                function calcZoneTimeLeft(event) {
                    var timeLeft_Sec = event.timeUnit == 'minute' ? event.timeLeft * 60 : event.timeLeft;

                    var serverUTC = new Date().getTime() + onlineProvider.getDiffUTC();  // server current time
                    var deffBetweenLastUbdateToEventTime = (serverUTC - event.lastUpdate);
                    var newTimeLeft = timeLeft_Sec - (deffBetweenLastUbdateToEventTime / 1000);  //ex' last update 8:00:00 time left 7 min  ; now 08:00:30 ---> deffBetweenLastUbdateToEventTime = 30   ---> newTimeLeft = 6:30 minutes
                    if (newTimeLeft < 2) {
                        $scope.timeLeftStr = null;
                        return;
                    }

                    //calc the diff between the two:
                    //      a. local time left (timeLeft_Sec changed by timer)
                    //      b. server time left (newTimeLeft, calculted using the onlineProvider.getDiffUTC())
                    var diffTimeLeft = $scope.timeLeftStr ? Math.abs(newTimeLeft - $scope.timeLeft_Sec) : MAX_DIFF_ZONES_UPDATE + 1;
                    if (diffTimeLeft > MAX_DIFF_ZONES_UPDATE) {
                        $scope.timeLeft_Sec = newTimeLeft;
                        $scope.timeLeftStr = parseSecondsToStringDate(newTimeLeft);
                    }
                }
                //****************************************************************************
                function zoneIntervalFunction() {
                    if ($scope.timeLeftStr) {
                        if ($scope.timeLeft_Sec > 2) {
                            $scope.timeLeft_Sec--;
                            $scope.timeLeftStr = parseSecondsToStringDate($scope.timeLeft_Sec);
                        } else {
                            $scope.timeLeftStr = null;
                        }
                    }
                }
                //************************************************SetCallbackUp(scheduleConnector)******************************
                $scope.adviserConnector.SetCallbackUp(function (obj) {
                    //send to server accept suggistion
                    var promise = {
                        callback: null,
                        success: function (callback) {
                            this.callback = callback;
                        }

                    };
                    if (obj.service == "AcceptSuggestions") {
                        zoneProxy.AcceptSuggestions($scope.deviceId, $scope.zoneId, obj)//send to server accept suggistion servise not exists
                             .success(function (data) {
                                 promise.callback();
                                 //$scope.AcceptSuggestions(obj.suggestions);
                                 // buildObject(data);
                             });
                        
                        
                    } else { //save categories changes
                        //send to server saveCategories servise not exists
                        //zoneProxy.saveCategories($scope.deviceId, $scope.zoneId, obj)
                        //    .success(function (data) {
                        //        promise.callback();
                              
                        //    });
                        zoneProxy.AcceptSuggestions($scope.deviceId, $scope.zoneId, obj)//send to server accept suggistion servise not exists
                             .success(function (data) {
                                 promise.callback();
                                 //$scope.AcceptSuggestions(obj.suggestions);
                                 // buildObject(data);
                             });
                    }
                    return promise;
                   
                });
                //********************************************************************
                $scope.OddEvenConnector.SetCallbackUp(function (data) {
                    $scope.scheduleView.totalWeeklyMinutes = data;
                });
                //************************************************SetCallbackUp(scheduleConnector)******************************
                $scope.scheduleConnector.SetCallbackUp(function () {
                    var totalDays = [];
                    var totalMinutes = 0;
                    for (var i = 0; i < $scope.scheduleView.rows.length; i++) {
                        for (var j = 0; j < $scope.scheduleView.rows[i].days.length; j++) {
                            totalMinutes += parseInt($scope.scheduleView.rows[i].days[j].duration == null? 0 : $scope.scheduleView.rows[i].days[j].duration /60);
                            totalDays[j] = (totalDays[j] || 0) + parseInt($scope.scheduleView.rows[i].days[j].duration || 0);
                        }
                    }
                    var totalDaysCount = 0;
                    for (var i = 0; i < totalDays.length; i++) {
                        totalDaysCount += totalDays[i] > 0 ? 1 : 0;
                    }
                    $scope.scheduleView.totalWeeklyMinutes = totalMinutes;
                    $scope.scheduleView.totalWeeklyDays = totalDaysCount;
                });
                //************************************************buildObject******************************
                var buildObject = function (data) {
                    $scope.zone = data.body;
                    $scope.zoneNumber = data.body.zoneNumber;
                    $scope.categoriesView = data.body.categoriesView;
                  //  $scope.irrigationSuggestions = data.body.irrigationSuggestions;
                  //  $scope.acceptRecommendation = data.body.irrigationSuggestions.isAccepted;
                    $scope.scheduleView = data.body.scheduleView;
                    $scope.settings = data.body.settings;
                    $scope.flowSensorSettings = data.body.flowSensorSettings;
                    $scope.$emit('zoneLoad');
                    onlineProvider.registerDevice(OnlineEvents, $scope.deviceId, 'zoneOnline', onlineCBfuncZonePage);
                    fixLoadingOff();
                }
                //************************************************getZoneDetails******************************
                $scope.getZoneDetails = function (controllerId, zoneId) {
                    zoneProxy.getZoneDetails(controllerId, zoneId)
                   .success(function (data) {
                       buildObject(data);
                   });
                }
                //************************************************AcceptSuggestions******************************
                $scope.AcceptSuggestions = function (suggestions) {
                   
                    zoneProxy.AcceptSuggestions($scope.deviceId, $scope.zoneId, suggestions)
                       .success(function (data) {
                           buildObject(data);
                         
                       });
                }
                //************************************************saveTableIrrigationByZone******************************
                $scope.saveTableIrrigationByZone = function () {
                    $scope.ladda.schedule = true;
                    zoneProxy.saveTableIrrigationByZone($scope.deviceId, $scope.zoneId, $scope.scheduleView.scheduleType, $scope.scheduleView)
                            .success(function (data) {

                                 mainRouter.callkey("showRecomendationEvent", {});
                                 $scope.ladda.schedule = false;
                                 toastr.success('Settings  Saved', 'Success!');
                            });
                }
                //************************************************saveSettings******************************
                $scope.saveSettings = function () {
                    $scope.ladda.settings = true;
                    zoneProxy.saveSettings($scope.deviceId, $scope.zoneId, $scope.settings)
                   .success(function (data) {
                       toastr.success('Settings  Saved', 'Success!');
                       $scope.ladda.settings = false;
                   });
                }
                //************************************************SaveflowSensorSettings******************************
                $scope.SaveflowSensorSettings = function () {
                    $scope.ladda.flow = true;
                    zoneProxy.flowSensorSettings($scope.deviceId, $scope.zoneId, $scope.flowSensorSettings)
                   .success(function (data) {
                       toastr.success('Settings  Saved', 'Success!');
                       $scope.ladda.flow = false;
                   });
                }
          
                //************************************************getZoneSaggestionWizard******************************
                $scope.getZoneSaggestionWizard = function () {
                    zoneProxy.getZoneSaggestionWizard($scope.deviceId, $scope.zoneId).success(function (data) {
                        $scope.categories = buildingZones(data.body);
                        var obj = {
                            categories: $scope.categories,
                            suggestions: $scope.irrigationSuggestions
                        }
                        $scope.adviserConnector.CallbackDown(obj);
                        
                    });

                }
                //*****************************************************
                $scope.changeZoneName = function (sn, zoneId, name) {
                    zoneProxy.changeZoneName(sn, zoneId, name)
                    .success(function (data) {

                    }).error(function (data, status, headers, config) {
                        toastr.error($filter('translate')('toastrErrMsgGet'));
                    });
                }
                //*****************************************************************************************
                function stringTimeToSeconds(strTime) {
                    if (!strTime) {
                        return 0;
                    }
                    return parseInt(strTime.Hours) * 3600 + parseInt(strTime.Minutes) * 60 + parseInt(strTime.Seconds);
                }
                //****************************************************
                $scope.startManualOperation = function (time) {
                    deviceProxy.manualZoneOperationOnline($scope.deviceId, $scope.zoneId, stringTimeToSeconds(time))
                        .success(function (data, status, headers, config) {

                        }).error(function (data, status, headers, config) {

                        });
                    //*****************
                    $('#setZoneTimeZonePage').modal('hide');
                }
                //***********************************************
                function buildingZones(SuggetionsTypes) {
                    var oneZone = {
                        zoneName: "",
                        zoneId: 0,
                        acceptSuggestions: false,
                        plantType: {
                            selected: {},
                            restType: {},
                            advisorTypeID:10
                        },
                        slopeType: {
                            selected: {},
                            restType: {},
                            advisorTypeID: 10
                        },
                        soilType: {
                            selected: {},
                            restType: {},
                            advisorTypeID:10
                        },
                        sprinklerType: {
                            selected: {},
                            restType: {},
                            advisorTypeID: 10
                        },
                        sunExposureType: {
                            selected: {},
                            restType: {},
                            advisorTypeID: 10
                        }

                    }
                    for (var key1 in SuggetionsTypes) {
                        if (SuggetionsTypes.hasOwnProperty(key1)) {
                            var Type = SuggetionsTypes[key1];
                            if (Type.optionalValues) {
                                oneZone[key1].restType = jQuery.extend(true, {}, Type.optionalValues);
                                oneZone[key1].advisorTypeID = Type.advisorTypeID;
                                for (var i = 0; i < Type.optionalValues.length; i++) {
                                    if (Type.optionalValues[i].isSelected) {
                                        oneZone[key1].selected = jQuery.extend(true, {}, Type.optionalValues[i]);

                                        break;
                                    }
                                }
                            }
                        }
                    }
                    return oneZone;
                  


                   
                }

                //****************************************************
                mainRouter.register("refreshZonePage", function (data) {
                    zoneProxy.getZoneSchedule($scope.deviceId, $scope.zoneId)
                       .success(function (data) {
                           $scope.scheduleView = data.body;
                           $scope.refreshTable++;
                           $scope.$apply();
                       });
                });
                //***********************************************************
                onlineProvider.registerIntervalCallback(zoneIntervalFunction);

                //*********************************zoneImage******************************
                function resetLoading() {

                    $('.zoneFixLoadingImage').css({ 'display': 'none' });
                    fill.width('0');
                    precent.html(0 + "%");


                }
                //*******************************************************************
                $scope.myANCallback = function (val) {

                    $('.zoneFixLoadingImage').css({ 'display': 'block' });
                    precent = $('.loadingContainer .precent');
                    fill = $('.loadingContainer .loadingBar .fill');
                };
                //***************************************************************
                $scope.myCallback = function (valueFromDirective) {
                    $scope.ladda.uploadFile = false;
                    if (valueFromDirective.body) {

                        $scope.zone.imageURI = valueFromDirective.body;
                        $scope.$apply();
                       resetLoading();
                        toastr.success('New Image  Saved', 'Success!');
                    } else {
                        resetLoading();
                        toastr.error('Faild Upload Image', 'Error!');
                    }

                };
                //************************************************************
                $scope.progress = function (val) {  // full width = 216px
                    precent.html(parseInt(val) + "%");
                    var currentWidth = parseInt((val / 100) * 216);
                    fill.width(currentWidth);
                    $scope.$apply();

                };
                //**************************************************
            }],
            //************************************************link***************************************
            link: function (scope, element, attrs, ngModel) {
                scope.getZoneDetails(scope.deviceId, scope.zoneId)
                scope.getZoneSaggestionWizard();
            }
        };//return
    }
})(angular);

var LanguagePrefix = ROOT_ADDR.SYSTEM_ACCOUNT_ROOT + "/Files/laguage/";

(function (angular) {
    var selectedLanguage;
    var app = angular.module(
        "mainApp",
        ["myApp.templates"
        , "ui.router"
        , 'ngMessages'
        , 'ngSimpleUpload'
        , 'module.welcome'
        , 'module.allAlerts'
        , 'ngSanitize'
        , 'angular-ladda'
        , "module.main"
        , "module.project"
        , "module.httpProxies"
        , "module.menuNavigation"
        , "module.site"
        , "module.device"
        , "module.XCI.Device"
        , "module.GSI.Device"
        , "module.GSI.Device.Settings"
        , "module.XCI.zones"
        , "module.weather.forecast"
        , "module.accessories"
        , "module.message"
        , "module.translate"
        , "module.filters"
        , "module.support"
        , "pascalprecht.translate"
        , "tmh.dynamicLocale"
        , "angularTreeview"
        ]);

    //***********************************************
    function getCookie(cname) {
        var name = cname + "=";
        var ca = document.cookie.split(';');
        for (var i = 0; i < ca.length; i++) {
            var c = ca[i];
            while (c.charAt(0) == ' ') c = c.substring(1);
            if (c.indexOf(name) == 0) return c.substring(name.length, c.length);
        }
        return "";
    }
    //************************************************
    var getParameterByName = function (name) {
        name = name.replace(/[\[]/, "\\\[").replace(/[\]]/, "\\\]");
        var regex = new RegExp("[\\?&]" + name + "=([^&#]*)"), results = regex.exec(location.search);
        return results == null ? "" : decodeURIComponent(results[1]);
    };
    //*************************************************************************************
    function setCookie(cname, cvalue, exdays) {
        var d = new Date();
        d.setTime(d.getTime() + (exdays * 24 * 60 * 60 * 1000));
        var expires = "expires=" + d.toUTCString();
        document.cookie = cname + "=" + cvalue + "; " + expires;
    }
    //*************************************************************************************
    
    app.factory('RequestService', function RequestService() {

        var AccessTokenAccount = getCookie('AccessTokenAccount');
        var request = function request(config) {
            if (config.url.indexOf(LanguagePrefix) >= 0
                || config.url.indexOf("maps.googleapis.com") >= 0) {
            }
            else {
                if (AccessTokenAccount) {
                    config.headers['Authorization'] = 'Bearer ' + AccessTokenAccount;
                    clearTimeWD();

                }
            }
            return config;
        }

        return {
            request: request
        }
    });


    app.config(['$stateProvider', '$urlRouterProvider', '$translateProvider', 'tmhDynamicLocaleProvider','$httpProvider', 
        function ($stateProvider, $urlRouterProvider, $translateProvider, tmhDynamicLocaleProvider, $httpProvider) {
            $httpProvider.interceptors.push('RequestService');
            //default language
            if (getCookie("selectedLanguage") != "undefined"){
                selectedLanguage = getCookie("selectedLanguage")
            }else{
                selectedLanguage = 'en';
            }
                  
            //fallback language if entry is not found in current language
            $translateProvider.fallbackLanguage('en');
            //load language entries from files
            $translateProvider.useStaticFilesLoader({
                prefix: LanguagePrefix,
               // prefix: 'laguage/',
                suffix: '.txt' //file extension
            });
            $translateProvider.useSanitizeValueStrategy(null);

            tmhDynamicLocaleProvider.localeLocationPattern(ROOT_ADDR.SYSTEM_ACCOUNT_ROOT_INDEX + '/Files/vendor/angular/i18n/angular-locale_{{locale}}.js')





    }])

    app.run(
           ['$rootScope', '$state', '$stateParams', '$translate', 'tmhDynamicLocale', '$rootScope', 'user', 'mainRouter','onlineProvider', 'mainProvider', 'translate',
           function ($rootScope, $state, $stateParams, $translate, tmhDynamicLocale, $rootScope, user, mainRouter, onlineProvider, mainProvider, translate) {
  
            $rootScope.$state = $state;
            $rootScope.$stateParams = $stateParams;
            $translate.use(selectedLanguage);
            tmhDynamicLocale.set(selectedLanguage);
            
            $rootScope.arrHistory = [];
            //$rootScope.$on("$stateChangeSuccess", function (event, toState, toParams, fromState, fromParams) {
            //    var from = fromState.name.substr(0, fromState.name.indexOf('.'));
            //    var to = toState.name.substr(0, toState.name.indexOf('.'));
            //    if (from == 'device' && to == 'site') {
            //        mainRouter.callkey("tree", '');
            //    }
 
            //});
           

            var AccessTokenAccount = getCookie('AccessTokenAccount');

            if (!AccessTokenAccount.length) {

                window.location = MAIN_LINKS.LOGIN.link + "&returnUrl=" + encodeURIComponent(window.location.href);
               

            } else {
                onlineProvider.init(ROOT_ADDR.ONLINE_SERVER, AccessTokenAccount)
                var userProvider = user;
                //request for token exchange
                var data1 = {
                    accountToken: AccessTokenAccount,
                    u:user
                };
                var postRequest = $.ajax({

                    type: "GET",
                    contentType: "application/json",
                    url: ROOT_ADDR.MF_API + "/Admin/Project/Exchange",
                    beforeSend: function (xhr) {
                        xhr.setRequestHeader("Authorization", 'Bearer ' + data1.accountToken);
                    },
                 
                    dataType: "json",
                    success: function (data) {

                        

                        var data = data.body;
                        mainProvider.ExchangeNevigation.data.loginExchangeView = data.loginExchangeView;

                        translate.UpdateGMT_Offset(data.timeZoneView * 60 * 1000);
                        user.setUser(data);
                        if (window.location.hash) {
                            //user enter the site directly with token 
                            var hash = window.location.hash;
                            if (hash.indexOf("site") !=-1) {
                                var id = hash.split(/[site//]/)[6];
                                mainProvider.ExchangeNevigation.data.loginExchangeView = "Site";
                                mainProvider.ExchangeNevigation.data.id = id;
                            }
                            if (hash.indexOf("device") != -1) {
                                var id = hash.split(/[device//]/)[8];
                                var type = hash.split(/[device//]/)[11];
                                mainProvider.ExchangeNevigation.data.loginExchangeView = "Device";
                                mainProvider.ExchangeNevigation.data.id = id;
                                mainProvider.ExchangeNevigation.data.type = type;
                            }
                            if (hash.indexOf("Welcome") != -1) {
                               
                                mainProvider.ExchangeNevigation.data.loginExchangeView = "Welcome";
                            }
                        } else {

                            if (data.loginExchangeView == "Device") { //go to device

                              
                                mainProvider.ExchangeNevigation.data.id = data.entry_SN;
                                
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
                                        mainProvider.ExchangeNevigation.data.type = data2.name;
                                        if (data2.name == "GSI" || data2.name == "GSI-AG") {
                                            $state.go('device.GSI_device.online', { siteId: data.entry_siteID, deviceId: data.entry_SN, typeName: data2.name });
                                        } else if (data2.name == "XCI-WIFI" || data2.name == "XCI") {
                                            $state.go('device.XCI_device.online', { siteId: data.entry_siteID, deviceId: data.entry_SN, typeName: data2.name });
                                        }
                                       
                                    },
                                    error: function (data) {

                                    }
                                });
                            }
                            else if (data.loginExchangeView == "Site") {//go to site
                             
                                $state.go('site.preview.map', { siteId: data.entry_SiteID });

                                mainProvider.ExchangeNevigation.data.id = data.entry_SiteID;
                            }
                         
                            else if (data.loginExchangeView == "Welcome") { //go to welcome
                                $state.go('welcome');
                            }
                            else if (data.loginExchangeView == "Project") { //go to site

               
                                mainProvider.ExchangeNevigation.data.id = data.entry_ProjectID;

                                $state.go('site.preview.map', { siteId: data.entry_ProjectID });
                            }


              

                        }
                    },
                    error: function (data) {

                    }

                        });

             
           }
         
        }
      ]
    )

})(angular);
