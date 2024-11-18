
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site.stats')
        .directive('usageLogDirective', usageLogDirectiveFactory);
    /********************************************************************usageLogDirectiveFactory****************************************************************************************************/
    function usageLogDirectiveFactory($log) {



        return {
            restrict: 'EA',
            require: '?ngModel',
            scope: {},
            templateUrl: 'app/modules/module.site/module.stats/usageLog.html',
            controller: ['$scope', 'statsProxy', '$filter', 'translate', 'directiveComm', function ($scope, statsProxy, $filter, translate, directiveComm) {
              //************************************************Attributs*******************
              var PageSize = 10;
              $scope.usageConnector = directiveComm.CreateConnector();
              $scope.CostomDate = {
                    'startUnix': '',
                    'endUnix': '',
                    'startStr': '',
                    'endStr': ''
                };
                var date = {
                      'startUnix': '',
                      'endUnix': ''
                };
                $scope.ladda = {
                    "usageLoad": false,
                    "filter": false,
                    "csv": false  
                };
                //************************************************functions*******************
                //***********************UnixTime(Outer)****************
                $scope.UnixTime = function (local , param) {
                    var unixInt = parseInt(local);
                    var str = $filter('date')(local, 'mediumDate');
                    if (param == 0) {
                        $scope.CostomDate.startStr = str;
                        $scope.CostomDate.startUnix = translate.fullDateStringToUnixServer(str, "00:00")
                    } else {
                        $scope.CostomDate.endStr = str;
                        $scope.CostomDate.endUnix = translate.fullDateStringToUnixServer(str, "00:00")
                    }
                }
                //***********************usageConnector.SetCallbackUp(Outer)****************
                $scope.usageConnector.SetCallbackUp(function (pageNumber) { 

                    $scope.getUsageLog(pageNumber, date);

                });
                //***********************GetTopUsageLog(Outer)****************
                $scope.GetTopUsageLog = function (id, type) {
                    $scope.logsBy = 'Top';
                    $scope.pagerFlag = false;
                    switch (type) {
                        case 0:
                            statsProxy.GetTopUsageLogSite(id, PageSize)
                              .success(function (data) {
                                  $scope.usageLog = data.body;
                                  $scope.ladda.usageLoad = false;
                       });
                            break;
                        case 1:
                            statsProxy.GetTopUsageLogDevice(id)
                              .success(function (data) {
                                  $scope.usageLog = data.body;
                                  $scope.ladda.usageLoad = false;
                              });
                            break;
                    }
                    fixLoadingOff();
                }
                //***********************GetDates(Outer)****************
                $scope.GetDates = function (search) {

                    $scope.ladda.usageLoad = true;
                    switch (search) { // return start and end date
                        case 'Top':
                            $scope.logsBy = 'Top';
                            $scope.costom = false;
                            $scope.GetTopUsageLog($scope.id, $scope.type);
                            break;
                        case 'lastYear':
                            $scope.logsBy = 'lastYear';
                            $scope.costom = false;
                            date = translate.getLastYear();
                            $scope.getUsageLog(1, date);
                            break;
                        case 'lastMonth':
                            $scope.logsBy = 'lastMonth';
                            $scope.costom = false;
                            date = translate.getLastMonth();
                            $scope.getUsageLog(1, date);
                            break;
                        case 'lastWeek':
                            $scope.logsBy = 'lastWeek';
                            $scope.costom = false;
                            date = translate.getLastWeek();
                            $scope.getUsageLog(1, date);
                            break;
                        case 'Costom':
                            $scope.logsBy = 'Costom';
                            $scope.costom = true;
                            $scope.ladda.usageLoad = false;
                            break;
                    }

                  

                }
                //***********************filter(Outer)****************
                $scope.filter = function () {
                    $scope.ladda.filter = true;
                    $scope.getUsageLog(1, $scope.CostomDate);
                    
                }
                //***********************getUsageLog(Outer)****************
                $scope.getUsageLog = function (currentPage, date) {

                    switch ($scope.type) {
                        case 0:
                            $scope.currentPage = currentPage;
                            statsProxy.getUsageLogSite($scope.id, $scope.type, date, $scope.currentPage)
                              .success(function (data) {

                                  $scope.pagerFlag = true;
                                  $scope.usageLog = data.body;
                                  $scope.usageConnector.CallbackDown(currentPage, PageSize, data.body.metadata.totalItems);
                                  $scope.ladda.usageLoad = false;
                                  $scope.ladda.filter = false;
                              });
                            break;
                        case 1:
                            
                            break;
                    }

                }

            }],
            //**********************************************************Link****************
            link: function (scope, element, attrs, ngModel) {
                if (!ngModel) return;
                ngModel.$render = function () {
                    if (attrs.type == 'site') {
                        
                        scope.type = 0; //logs for site
                    }
                    if (attrs.type == 'device') {
                   
                        scope.type = 1; //log for device
                    }
                    scope.id = ngModel.$viewValue;
                    scope.GetTopUsageLog(scope.id, scope.type);
                };


            }




        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);






