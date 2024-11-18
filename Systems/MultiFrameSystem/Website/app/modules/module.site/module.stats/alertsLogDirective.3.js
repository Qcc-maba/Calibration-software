
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site.stats')
        .directive('alertLogDirective', alertLogDirectiveFactory);
    /********************************************************************AlertsLogDirectiveFactory****************************************************************************************************/
    function alertLogDirectiveFactory() {



        return {
            restrict: 'EA',
            require: '?ngModel',
            scope:{
            },
            templateUrl: 'app/modules/module.site/module.stats/alertsLog.html',
            controller: ['$scope', 'statsProxy', '$filter', 'translate', 'directiveComm', function ($scope, statsProxy, $filter, translate, directiveComm) {
                //************************************************Attributs*******************
                var PageSize = 10;
                $scope.AlertsConnector = directiveComm.CreateConnector();
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
                    "alertLoad": false,
                    "filter": false,
                    "csv": false
                };
                //************************************************functions*******************
                //***********************UnixTime(Outer)****************
                $scope.UnixTime = function (local, param) {
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
                //***********************AlertsConnector.SetCallbackUp(Outer)****************
                $scope.AlertsConnector.SetCallbackUp(function (pageNumber) {  //
                    $scope.getAlertsLog(pageNumber, date);
                });

                //***********************GetTopAlertsLog(Outer)****************
                $scope.GetTopAlertsLog = function (id, type) {
                    $scope.logsBy = 'Top';
                    $scope.pagerFlag = false;
                    switch (type) {
                        case 0:
                            statsProxy.GetTopAlertsLogSite(id, PageSize)

                              .success(function (data) {
                                  $scope.AlertsLog = data.body;
                                  $scope.ladda.alertLoad = false;
                              });
                            break;
                        case 1:
                            statsProxy.GetTopAlertsLogDevice(id)

                              .success(function (data) {
                                  $scope.AlertsLog = data.body;
                                  $scope.ladda.alertLoad = false;
                              });
                            break;
                    }
                    fixLoadingOff();

                }
                //***********************GetDates(Outer)****************
                $scope.GetDates = function (search) {

                    $scope.ladda.alertLoad = true;
                    switch (search) { // return start and end date
                        case 'Top':
                            $scope.logsBy = 'Top';
                            $scope.costom = false;
                            $scope.GetTopAlertsLog($scope.id, $scope.type);
                            break;
                        case 'lastYear':
                            $scope.logsBy = 'lastYear';
                            $scope.costom = false;
                            date = translate.getLastYear();
                            $scope.getAlertsLog(1, date);
                            break;
                        case 'lastMonth':
                            $scope.logsBy = 'lastMonth';
                            $scope.costom = false;
                            date = translate.getLastMonth();
                            $scope.getAlertsLog(1, date);
                            break;
                        case 'lastWeek':
                            $scope.logsBy = 'lastWeek';
                            $scope.costom = false;
                            date = translate.getLastWeek();
                            $scope.getAlertsLog(1, date);
                            break;
                        case 'Costom':
                            $scope.logsBy = 'Costom';
                            $scope.costom = true;
                            $scope.ladda.alertLoad = false;
                            break;
                    }



                }

                //***********************filter(Outer)****************
                $scope.filter = function () {
                    $scope.ladda.filter = true;
                    $scope.getAlertsLog(1, $scope.CostomDate);
                }

                //***********************getAlertsLog(Outer)****************
                $scope.getAlertsLog = function (currentPage, date) {

                    switch ($scope.type) {
                        case 0:
                            $scope.currentPage = currentPage;
                            statsProxy.getAlertsLogSite($scope.id, $scope.type, date, $scope.currentPage)
                              .success(function (data) {

                                  $scope.pagerFlag = true;
                                  $scope.AlertsLog = data.body;
                                  $scope.AlertsConnector.CallbackDown(currentPage, PageSize, data.body.metadata.totalItems);
                                  $scope.ladda.alertLoad = false;
                                  $scope.ladda.filter = false;
                              });
                            break;
                        case 1:
                            $scope.ladda.alertLoad = false;
                            $scope.ladda.filter = false;
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
                    scope.GetTopAlertsLog(scope.id, scope.type);
                };


            }




        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);






