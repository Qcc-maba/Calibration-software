(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('color', colorFactory);



    function colorFactory($log) {
        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.widgets/color/changeColor.html',

            controller: function ($scope) {
            
              
                $scope.str = localStorage.getItem("css") || "/Content/css/colorGreyNew.css";
                if ($scope.str.indexOf("colorGreyNew.css")!=-1) {
                    localStorage.setItem('cssType', 'dark');
                } else {
                    localStorage.setItem('cssType', 'bright');
                }
                $scope.changeCssTo = function (col) {
                    switch (col) {
                        case 'Dark':
                            $scope.str = "/Content/css/colorGreyNew.css";
                            localStorage.setItem("css", "/Content/css/colorGreyNew.css");
                            localStorage.setItem('cssType', 'dark');
                            break;
                        case 'White':
                            $scope.str = "/Content/css/theme_light.css";
                            localStorage.setItem("css", "/Content/css/theme_light.css ");
                            localStorage.setItem('cssType', 'bright');
                            break;
                    }
                }





            },
            link: function (scope, element, attrs, ngModel) {


            }




        };

    }
})(angular);