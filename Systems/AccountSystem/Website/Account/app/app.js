var LanguagePrefix = "../../Content/laguage/";
(function (angular) {
    var app = angular.module("mainApp",
        ["myApp.templates"
         , "ui.router"
         , "module.admin"
         , "module.profile"
         , "ngMessages"
         , "module.httpProxies"
         ,"module.accessories"
         , "module.menuNavigation"
         , "module.widgets"
         , "angular-ladda"
         , "pascalprecht.translate"
         , "tmh.dynamicLocale"
         , "ngSimpleUpload"
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
    app.factory('RequestService', function RequestService() {

        var AccessTokenAccount = getCookie('AccessTokenAccount');
        var request = function request(config) {
            if (config.url.indexOf(LanguagePrefix) >= 0) {
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
    
    
   
    app.config(
                ['$httpProvider','$translateProvider','tmhDynamicLocaleProvider',
    function ($httpProvider, $translateProvider, tmhDynamicLocaleProvider) {
           
            $httpProvider.interceptors.push('RequestService');
            //default language
            selectedLanguage = getCookie("selectedLanguage") || 'en';
            //fallback language if entry is not found in current language
            $translateProvider.fallbackLanguage('en');
            //load language entries from files
            $translateProvider.useStaticFilesLoader({
                prefix: '/Content/laguage/',
                suffix: '.txt' //file extension
            });
            $translateProvider.useSanitizeValueStrategy(null);

            tmhDynamicLocaleProvider.localeLocationPattern('/Content/laguage/angular-locale_{{locale}}.js')
        }
                ]
    )
    app.run(
                ['$rootScope', '$state', '$stateParams' , '$translate', 'tmhDynamicLocale',
        function ($rootScope, $state, $stateParams, $translate, tmhDynamicLocale) {
            
            $rootScope.$state = $state;
            $rootScope.$stateParams = $stateParams;
            $translate.use(selectedLanguage);
            tmhDynamicLocale.set(selectedLanguage);


            
        }
                ]
    )

})(angular);
