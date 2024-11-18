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