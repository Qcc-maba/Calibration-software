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





