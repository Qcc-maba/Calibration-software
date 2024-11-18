
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site.stats')
        .directive('chartsDirective', chartsDirectiveFactory);
    /*********************************************************************************************************************************************************************/
    function chartsDirectiveFactory($log) {



        return {
            restrict: 'EA',
            require: '?ngModel',
            templateUrl: 'app/modules/module.site/module.stats/charts.html',

            controller: function ($scope, statsProxy, $filter, translate) {
             
                $scope.costom = false;
                $scope.radioType = 'Duration';
                $scope.chartsBy = 'lastWeek';

                //***********************GetDates(Outer)****************
                $scope.GetDates = function (search) {
                    var date;
                    
                    switch (search) { // return start and end date
                      
                        case 'lastYear':
                            $scope.chartsBy = 'G_LAST_YEAR';
                            $scope.costom = false;
                            date = translate.getLastYear();
                            $scope.GetStackDetails(date);
                            break;
                        case 'lastMonth':
                            $scope.chartsBy = 'G_LAST_MONTH';
                            $scope.costom = false;
                            date = translate.getLastMonth();
                            $scope.GetStackDetails(date);
                            break;
                        case 'lastWeek':
                            $scope.chartsBy = 'G_LAST_WEEK';
                            $scope.costom = false;
                            date = translate.getLastWeek();
                            $scope.GetStackDetails(date);
                            break;
                        case 'Costom':
                            $scope.chartsBy = 'G_CUSTOM';
                            $scope.costom = true;
                            $scope.GetStackDetails(date);
                            break;
                    }



                }

                //*********************************************************

                $scope.radioCange = function (type) {
                    $scope.radioType = type;
                    organize_data($scope.stackDetails);

                }

                function organize_data(data) {


                    $scope.stackDetails = data;
                    $scope.Sum = {
                        savingDuration: 0,
                        savingQuantity: 0,
                        usedDuration: 0,
                        usedQuantity: 0,
                        type: $scope.radioType


                    };

                    for (var i = 0; i < data.length; i++) {
                         $scope.Sum.savingDuration =  $scope.Sum.savingDuration + parseInt(data[i].savingDuration);
                         $scope.Sum.savingQuantity =  $scope.Sum.savingQuantity + parseInt(data[i].savingQuantity);
                         $scope.Sum.usedDuration =  $scope.Sum.usedDuration + parseInt(data[i].usedDuration);
                         $scope.Sum.usedQuantity =  $scope.Sum.usedQuantity + parseInt(data[i].usedQuantity);
                    }

                    $scope.pieDetails = $scope.Sum;

                    $scope.stackBarMatrix = new Array($scope.stackDetails.length);
                    for (var i = 0; i < $scope.stackDetails.length; i++) {
                        $scope.stackBarMatrix[i] = new Array(3);

                        if ($scope.radioType == "Duration") {
                            $scope.stackBarMatrix[i][0] = $filter('date')($scope.stackDetails[i].date, 'mediumDate');
                            $scope.stackBarMatrix[i][1] = parseInt($scope.stackDetails[i].usedDuration);
                            $scope.stackBarMatrix[i][2] = parseInt($scope.stackDetails[i].savingDuration);
                        } else {
                            $scope.stackBarMatrix[i][0] = $filter('date')($scope.stackDetails[i].date, 'mediumDate');
                            $scope.stackBarMatrix[i][1] = parseInt($scope.stackDetails[i].usedQuantity);
                            $scope.stackBarMatrix[i][2] = parseInt($scope.stackDetails[i].savingQuantity);
                        }


                        $scope.stackBarMatrix[i][3] = '';

                    }
                    var first = ['Genre', 'used', 'saving', { role: 'annotation' }];
                    $scope.stackBarMatrix.unshift(first);
                    $scope.pieObj.changeData($scope.Sum);
                    $scope.stackBarObj.changeData($scope.stackBarMatrix);
                }


                $scope.GetStackDetails = function (date) {
                    statsProxy.GetStackDetails($scope.siteId, date.startUnix, date.endUnix)
                   .success(function (data) {
                       organize_data(data);
                       fixLoadingOff();
                   });

                }

              
            },
            link: function (scope, element, attrs, ngModel) {

                scope.pieObj = {
                    data: null,
                    options: null,
                    changeOptionsCallback: null,
                    changeOptions: function (_options) {
                        this.options = _options;

                        if (this.changeOptionsCallback) {
                            this.changeOptionsCallback(_options);
                        }
                    },
                    changeData: function (_data) {
                        this.data = _data;

                        if (this.changeDataCallback) {
                            this.changeDataCallback(_data);
                        }
                    },
                    changeDataCallback: null
                };

                scope.stackBarObj = {
                    data: null,
                    options: null,
                    changeOptionsCallback: null,
                    changeOptions: function (_options) {
                        this.options = _options;

                        if (this.changeOptionsCallback) {
                            this.changeOptionsCallback(_options);
                        }
                    },
                    changeData: function (_data) {
                        this.data = _data;

                        if (this.changeDataCallback) {
                            this.changeDataCallback(_data);
                        }
                    },
                    changeDataCallback: null
                };


                if (!ngModel) return;
                ngModel.$render = function () {
                    
                    scope.siteId = ngModel.$viewValue.toString();
                    scope.GetDates('lastWeek');

                };


            }




        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);






