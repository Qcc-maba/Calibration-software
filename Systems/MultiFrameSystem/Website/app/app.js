var LanguagePrefix = "/Content/laguage/";
var myMainProvider;
var myState;
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

        var request = function request(config) {
            if (config.url.indexOf(LanguagePrefix) >= 0
                || config.url.indexOf("maps.googleapis.com") >= 0) {
            }
            else {
                if (GLOBAL_DATA.accessToken) {
                    config.headers['Authorization'] = 'Bearer ' + GLOBAL_DATA.accessToken;
                    clearTimeWD();

                }
            }
            return config;
        }

        return {
            request: request
        }
    });


    app.config(['$stateProvider', '$urlRouterProvider', '$translateProvider', 'tmhDynamicLocaleProvider', '$httpProvider',
        function ($stateProvider, $urlRouterProvider, $translateProvider, tmhDynamicLocaleProvider, $httpProvider) {
            $httpProvider.interceptors.push('RequestService');
            //default language
            if (getCookie("selectedLanguage") != "undefined") {
                selectedLanguage = getCookie("selectedLanguage")
            } else {
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

            tmhDynamicLocaleProvider.localeLocationPattern('/Content/laguage/angular-locale_{{locale}}.js')

        }])

    app.run(
           ['$rootScope', '$state', '$stateParams', '$translate', 'tmhDynamicLocale', '$rootScope', 'user', 'mainRouter', 'onlineProvider', 'mainProvider', 'translate',
           function ($rootScope, $state, $stateParams, $translate, tmhDynamicLocale, $rootScope, user, mainRouter, onlineProvider, mainProvider, translate) {
               myMainProvider = mainProvider;
               $rootScope.$state = $state;
               myState = $state;
               $rootScope.$stateParams = $stateParams;
               $translate.use(selectedLanguage);
               tmhDynamicLocale.set(selectedLanguage);

               $rootScope.arrHistory = [];

               if (navigator.userAgent.match(/Android/i)
               || navigator.userAgent.match(/webOS/i)
               || navigator.userAgent.match(/iPhone/i)
               || navigator.userAgent.match(/iPad/i)
               || navigator.userAgent.match(/iPod/i)
               || navigator.userAgent.match(/BlackBerry/i)
               || navigator.userAgent.match(/Windows Phone/i)
               ) {
                   $rootScope.isPhone = true;
               }
               else {
                   $rootScope.isPhone = false;
               }
               $rootScope.$on("$stateChangeSuccess", function (event, toState, toParams, fromState, fromParams) {
                   if (fromState.name.indexOf('device.') > -1 && toState.name == 'device' && myMainProvider.goToSite) {
                       myState.go('site.preview.map', { siteId: myMainProvider.CurrentSite.data.siteId });
                   }
                   var to = toState.name.substr(0, toState.name.indexOf('.'));
                   if (to == 'site') {
                       $('.smallNavbarIcon').css({ 'display': 'block' });
                   } else {

                       $('.smallNavbarIcon').css({ 'display': 'none' });
                   }
                   myMainProvider.goToSite = true;
               });

               //init providers
               onlineProvider.init(ROOT_ADDR.ONLINE_SERVER, GLOBAL_DATA.accessToken);
               mainProvider.ExchangeNevigation.data.loginExchangeView = GLOBAL_DATA.exchangeData.loginExchangeView;
               translate.UpdateGMT_Offset(GLOBAL_DATA.userModel.timeZoneID * 60 * 1000);
               user.setUser(GLOBAL_DATA.userModel);

               //var userProvider = user;
               //request for token exchange
               /*var data1 = {
                   accountToken: AccessTokenAccount,
                   u: user
               };*/


               
               if (window.location.hash) {
                   //user enter the site directly with token 
                   var hash = window.location.hash;
                   if (hash.indexOf("site") != -1) {
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
                   if (hash.indexOf("support") != -1 || hash.indexOf("alerts") != -1) {
                       if (GLOBAL_DATA.exchangeData.loginExchangeView == 'Project') {
                           mainProvider.ExchangeNevigation.data.loginExchangeView = "Project";
                           mainProvider.ExchangeNevigation.data.id = GLOBAL_DATA.exchangeData.entry_ProjectID;
                       }
                       if (GLOBAL_DATA.exchangeData.loginExchangeView == 'Site') {
                           mainProvider.ExchangeNevigation.data.loginExchangeView = "Site";
                           mainProvider.ExchangeNevigation.data.id = GLOBAL_DATA.exchangeData.entry_SiteID || GLOBAL_DATA.exchangeData.entry_ProjectID;
                       }
                       if (GLOBAL_DATA.exchangeData.loginExchangeView == 'Device') {
                           mainProvider.ExchangeNevigation.data.loginExchangeView = "Device";
                           mainProvider.ExchangeNevigation.data.id = GLOBAL_DATA.exchangeData.entry_SN;
                       }

                   }
               } else {

                   if (GLOBAL_DATA.exchangeData.loginExchangeView == "Device") { //go to device


                       mainProvider.ExchangeNevigation.data.id = GLOBAL_DATA.exchangeData.entry_SN;

                       $state.go('device', { deviceId: GLOBAL_DATA.exchangeData.entry_SN, });
                   }
                   else if (GLOBAL_DATA.exchangeData.loginExchangeView == "Site") {//go to site

                       $state.go('site.preview.map', { siteId: GLOBAL_DATA.exchangeData.entry_SiteID });

                       mainProvider.ExchangeNevigation.data.id = GLOBAL_DATA.exchangeData.entry_SiteID;
                   }

                   else if (GLOBAL_DATA.exchangeData.loginExchangeView == "Welcome") { //go to welcome
                       $state.go('welcome');
                   }
                   else if (GLOBAL_DATA.exchangeData.loginExchangeView == "Project") { //go to site


                       mainProvider.ExchangeNevigation.data.id = GLOBAL_DATA.exchangeData.entry_ProjectID;

                       $state.go('site.preview.map', { siteId: GLOBAL_DATA.exchangeData.entry_ProjectID });
                   }




               }

           }]
    )

})(angular);
