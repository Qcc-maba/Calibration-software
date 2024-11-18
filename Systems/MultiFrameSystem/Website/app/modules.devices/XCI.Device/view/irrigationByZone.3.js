
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module("module.XCI.Device")
        .directive('irrigationByZone', irrigationByZoneFactory);
    /********************************************************************************************************************************************************************/
    function irrigationByZoneFactory() {

        return {
            restrict: 'EA',
            require: '?ngModel',
            scope: {
                scheduleview: '=',
                comm: '='
            },
            templateUrl: 'app/modules.devices/XCI.Device/view/irrigationByZone.html',
            controller:['$scope','$locale','translate', function ($scope,$locale,translate) {
                //********************************Attributes************************************
                $scope.locale = $locale;
                $scope.translate = translate;
               
                //**************************************************************************
                $scope.pharseTime = function (scheduleview) {
                    for (var i = 0; i < scheduleview.rows.length; i++) {
                        for (var j = 0; j < scheduleview.rows[i].days.length; j++) {
                            scheduleview.rows[i].days[j].durationStr = scheduleview.rows[i].days[j].duration / 60;
                        }
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
                   $scope.scheduleview.rows[index].sum = 0;
                    for (var i = 0; i <$scope.scheduleview.rows[index].days.length; i++) {
                        
                        $scope.scheduleview.rows[index].sum = $scope.scheduleview.rows[index].sum + parseInt($scope.scheduleview.rows[index].days[i].durationStr || 0);
                    }
                    for (var i = 0; i <$scope.scheduleview.rows[index].days.length; i++) {
                        if ($scope.scheduleview.rows[i]) {
                            $scope.sumAll = $scope.sumAll +$scope.scheduleview.rows[i].sum;
                        }
                        
                    }
                    return $scope.scheduleview.rows[index].sum;
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
