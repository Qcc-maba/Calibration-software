
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site.stats')
        .directive('general', generalFactory);
    /********************************************************************GeneralLogDirectiveFactory****************************************************************************************************/
    function generalFactory($log) {



        return {
            restrict: 'EA',
            require: '?ngModel',
            scope: {

            },
            templateUrl: 'app/modules/module.site/module.stats/statsGeneral.html',
            controller: ['$scope', 'statsProxy', '$filter', 'translate', 'directiveComm', function ($scope, statsProxy, $filter, translate, directiveComm) {
                //************************************************Attributs*******************
                var PageSize = 10;
                $scope.GeneralConnector = directiveComm.CreateConnector();
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
                    "generalLoad": false,
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
                //***********************GeneralConnector.SetCallbackUp(Outer)****************
                $scope.GeneralConnector.SetCallbackUp(function (pageNumber) {  //

                    $scope.getGeneralLog(pageNumber, date);

                });

                //***********************GetTopGeneralLog(Outer)****************
                $scope.GetTopGeneralLog = function (id, type) {
                    $scope.logsBy = 'Top';
                    $scope.pagerFlag = false;
                    switch (type) {
                        case 0:
                            statsProxy.GetTopGeneralLogSite(id, PageSize)

                              .success(function (data) {
                                  $scope.GeneralLog = data.body;
                                  $scope.ladda.generalLoad = false;
                              });
                            break;
                        case 1:
                            statsProxy.GetTopGeneralLogDevice(id)

                              .success(function (data) {
                                  $scope.GeneralLog = data.body;
                                  $scope.ladda.generalLoad = false;

                              });
                            break;
                    }

                    fixLoadingOff();
                }
                //***********************GetDates(Outer)****************
                $scope.GetDates = function (search) {
                    $scope.ladda.generalLoad = true;

                    switch (search) { // return start and end date
                        case 'Top':
                            $scope.logsBy = 'Top';
                            $scope.costom = false;
                            $scope.GetTopGeneralLog($scope.id, $scope.type);
                            break;
                        case 'lastYear':
                            $scope.logsBy = 'lastYear';
                            $scope.costom = false;
                            date = translate.getLastYear();
                            $scope.getGeneralLog(1, date);
                            break;
                        case 'lastMonth':
                            $scope.logsBy = 'lastMonth';
                            $scope.costom = false;
                            date = translate.getLastMonth();
                            $scope.getGeneralLog(1, date);
                            break;
                        case 'lastWeek':
                            $scope.logsBy = 'lastWeek';
                            $scope.costom = false;
                            date = translate.getLastWeek();
                            $scope.getGeneralLog(1, date);
                            break;
                        case 'Costom':
                            $scope.logsBy = 'Costom';
                            $scope.costom = true;
                            $scope.ladda.generalLoad = false;
                            break;
                    }



                }

                //***********************filter(Outer)****************
                $scope.filter = function () {
                    $scope.ladda.filter = true;
                    $scope.getGeneralLog(1, $scope.CostomDate);
                }


                //***********************getGeneralLog(Outer)****************
                $scope.getGeneralLog = function (currentPage, date) {

                    switch ($scope.type) {
                        case 0:
                            $scope.currentPage = currentPage;
                            statsProxy.getGeneralLogSite($scope.id, $scope.type, date, $scope.currentPage)
                              .success(function (data) {

                                  $scope.pagerFlag = true;
                                  $scope.GeneralLog = data.body;
                                  $scope.GeneralConnector.CallbackDown(currentPage, PageSize, data.body.metadata.totalItems);
                                  $scope.ladda.generalLoad = false;
                                  $scope.ladda.filter = false;
                              });
                            break;
                        case 1:
                            $scope.ladda.generalLoad = false;
                            $scope.ladda.filter = false;
                            break;
                    }






                }

                $scope.getLinkData = function (sn ,  connectionId) {
                  
                    switch ($scope.type) {
                        case 0:
                            statsProxy.getLinkData($scope.id,sn, connectionId)

                              .success(function (data) {
                                  $scope.linkLog = data.body;


                              });
                            break;
                        case 1:
                           
                            break;
                    }


                }




            }],
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
                    scope.GetTopGeneralLog(scope.id, scope.type);
                };


            }




        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);






