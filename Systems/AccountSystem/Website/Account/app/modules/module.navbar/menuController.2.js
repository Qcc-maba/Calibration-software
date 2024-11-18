(function (angular) {

    mi = angular
        .module('module.menuNavigation')
        .controller('menuController', menuController);

    function menuController($scope, $location, $http, adminProxy) {
        var runContainerHeight = function () {
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

        $scope.toggleNavigationMenu = function (event) {

            var toggleIcon = $(event.target).parent();

            if (toggleIcon[0].localName == "li") {
                toggleIcon = $(event.currentTarget);
            }
            if ($(toggleIcon).parent().children('ul').hasClass('sub-menu') && ((!$('body').hasClass('navigation-small') || $windowWidth < 767) || !$(toggleIcon).parent().parent().hasClass('main-navigation-menu'))) {
                if (!$(toggleIcon).parent().hasClass('open')) {
                    $(toggleIcon).parent().addClass('open');
                    $(toggleIcon).parent().parent().children('li.open').not($(toggleIcon).parent()).not($('.main-navigation-menu > li.active')).removeClass('open').children('ul').slideUp(200);
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

        function delete_cookie(name) {
            document.cookie = name + '=; expires=Thu, 01 Jan 1970 00:00:01 GMT;';
        }
        $scope.toggleNavbar = function () {
            if (!$('body').hasClass('navigation-small')) {
                $('body').addClass('navigation-small');
                $('#main-navigation-menu').hide();

            } else {
                $('body').removeClass('navigation-small');
                $('#main-navigation-menu').show();
            };
        }

        $scope.logOut = function () {

            window.location = MAIN_LINKS.LOGIN.link;
            delete_cookie('AccessTokenAccount');
        }

    
        $scope.nevigateToHomePage = function () {
            window.location = MAIN_LINKS.ACCOUNT_APP_LIST.link;
        }
        function reloadUser() {
             adminProxy.loadCurrentProfile()

                .success(function (data) {
                    $scope.name = data.body;

                });
        };
        reloadUser();
        //************************************
        function getParameterByName(name, url) {
            if (!url) url = window.location.href;
            name = name.replace(/[\[\]]/g, "\\$&");
            var regex = new RegExp("[?&]" + name + "(=([^&#]*)|&|#|$)"),
                results = regex.exec(url);
            if (!results) return null;
            if (!results[2]) return '';
            return decodeURIComponent(results[2].replace(/\+/g, " "));
        }
        
 








    }
})(angular);





