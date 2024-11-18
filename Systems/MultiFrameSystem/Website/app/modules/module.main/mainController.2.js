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
        $scope.logo = "/Content/img/logo_g.png";
        mainRouter.register("logo", function (logo) {
            $scope.logo = "/Content/img/"+logo;
        });
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
            window.location = MAIN_LINKS.LOGIN.link;
            delete_cookie("AccessTokenAccount");
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





