(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
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






