
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
