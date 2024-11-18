
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.menuNavigation')
        .directive('navbarDirective', navbarDirective);
        
    /**********************************************************************************************/
    function navbarDirective() {
        var navType = '';
        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.navbar/navbar.html',

            controller: ['$scope', 'projectProxy', 'directiveComm', '$state', 'siteProxy', '$timeout','mainRouter','$stateParams','$filter',
                function ($scope, projectProxy, directiveComm, $state, siteProxy, $timeout, mainRouter, $stateParams, $filter) {

                   
                    var $windowWidth;
                    var $windowHeight
                    var $pageArea
                    $scope.text = "";
                    $scope.pagerFlag = false;
                    var PageSize = 10;
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
                            mainNavigation.css('min-height', $('.mainNevigationWraper').height());
                        }
                        $("#page-sidebar .sidebar-wrapper").css('height', $windowHeight - $('body > .navbar').outerHeight()).scrollTop(0).perfectScrollbar('update');
                    };
                    ///**********************************************************GetProjects(Inner)*******************************************************
                    function GetProjects(currentPage, freeText) {
                        projectProxy.GetProjects(currentPage, freeText, PageSize)
                                         .success(function (data) {
                                             var data = data.body;
                                           
                                             PageSize = data.currentPageSize;
                                             $scope.totalProjects = data.totalProjects;
                                             $scope.projectsList = data.projects;
                                             var id = $scope.navbarType == 'menu' ? $state.params.siteId : $scope.projectsList[0].siteID;
                                             $scope[$scope.type] = $scope[$scope.type] || {};
                                             findCurrentSite($scope.projectsList, id);
                                           
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
                                             var data = data.body;
                                             PageSize = data.currentPageSize;
                                             $scope.totalProjects = data.totalProjects;
                                             $scope.projectsList = data.projects;
                                             $scope[$scope.type] = $scope[$scope.type] || {};
                                             var id = $scope.navbarType == 'menu' ? $state.params.siteId : $scope.projectsList[0].siteID;
                                             findCurrentSite($scope.projectsList, id);
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
                         
                            if ((projects[i].siteID == siteId)) {
                                $scope.choosenProject = projects[i].sharingData.rootSiteID;

                                $scope.siteName = projects[i].name;
                               
                                
                                $scope[$scope.type].currentNode = projects[i];
                                if ((projects[i].siteID == projects[i].rootProjectID) && ($scope.theSelected)) {
                                    //find and clear the selected item if exist
                                    $scope.theSelected.selected = null;
                                } else {
                                    projects[i].selected = 'selected';
                                    $scope.theSelected = projects[i];
                                }
                                if ($scope.navbarType == 'alerts') {
                                    mainRouter.callkey("treeAlertForSiteID", projects[i].siteID);
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
                      //  removeScrollToSmallViewBody();
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
                                   // runContainerHeight();
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
                        if ($(event)[0].target.className.indexOf("icon-arrow") != -1) {
                            return;
                        }
                        $scope.siteId = p.siteID || p.projectID;
                        if ($scope.navbarType == 'menu') {
                            if (p.selected != "selected") {
                               
                                findCurrentSite($scope.projectsList, $scope.siteId);
                                fixLoadingOn("goToSite", p.siteID || p.projectID);
                            }
                           
                            $scope.choosenProject = p.sharingData.rootSiteID;
                            // getSiteName(p.siteID);
                            if ($scope.siteId == $stateParams.siteId) {
                                addScrollToSmallViewBody();
                            }
                            $state.go('site.preview.map', { siteId: $scope.siteId });
                           
                        } else if(($scope.navbarType == 'checkBox')) {
                            if (p.parentSiteID == null) { //project
                                $scope.targetSiteTransfer = p.siteID;
                            }
                        }
                        else if (($scope.navbarType == 'alerts')) {
                            if (p.parentSiteID == null) { //project
                                if (p.selected != "selected") {

                                    findCurrentSite($scope.projectsList, p.siteID);
                             
                                }

                                $scope.choosenProject = p.sharingData.rootSiteID;
                 
                               
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
                              toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));

                          })
                          .error(function (data, status, headers, config) {
                              toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
                          });
                    }
                    //***********************************************
                    $scope.exchange = function () {

                        projectProxy.exchange()
                          .success(function (data, status, headers, config) {
                              data = data.body;
                              if (data.exchangeData.loginExchangeView == "Device") { //go to device
                                  $state.go('device', { deviceId: data.exchangeData.entry_SN, });
                              }
                              else if (data.exchangeData.loginExchangeView == "Site") {//go to site
                                  LastClickParam1 = data.entry_SiteID;

                                  LastAction = "goToSite";
                                  $state.go('site.preview.map', { siteId: data.exchangeData.entry_SiteID });
                                  mainRouter.callkey("tree", data.entry_siteID);
                              }

                              else if (data.exchangeData.loginExchangeView == "Welcome") { //go to welcome
                                  $state.go('welcome');

                              }
                              else if (data.exchangeData.loginExchangeView == "Project") { //go to project
                                  $state.go('site.preview.map', { siteId: data.exchangeData.entry_ProjectID });
                                  mainRouter.callkey("tree", data.exchangeData.entry_ProjectID);
                              }

                          })
                          .error(function (data, status, headers, config) {

                          });
                    }


                }],
                    //***************************************************link************************
            link: function (scope, element, attrs, ngModel) {

           
                scope.navbarType = attrs.atr;
                navType = attrs.atr
                if (scope.navbarType == 'menu') {
                    scope.type = 'abc';
               }else{
                    scope.type = 'abc';

               }
               
               
               

            }
        };
    }

                 /*******************************************************************************************************************************************************************************/

})(angular);






