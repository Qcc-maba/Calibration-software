(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.allAlerts')
        .directive('allAlerts', allAlertsFactory);



    function allAlertsFactory($log) {
        return {
            restrict: 'EA',
            
            templateUrl: 'app/modules/module.alert/allAlert.html',

            controller: ['$scope', 'projectProxy', 'mainRouter', 'profileProxy', 'directiveComm', function ($scope, projectProxy, mainRouter, profileProxy, directiveComm) {
                
                $scope.connector = directiveComm.CreateConnector();
                $scope.pageFitchers = {
                    includeSub:true
                }
            
                $scope.currentPage = 1;
                var PageSize = 6;
                $scope.pagerFlag = false;
                $scope.ladda = {
                    'allow': false,
                    'disable': false,
                    'save':false
                }
                //*********************************************************
                mainRouter.register("treeAlertForSiteID", function (data) {
                    $scope.projectNumber = data;
                    $scope.getAlerts();
                   
                });
               
                //*************************************************************
                $scope.macroAlerts = function (param) {
                    if (param == 0) {
                        param = true;
                        $scope.ladda.allow = true;
                    }else{
                        param = false;
                        $scope.ladda.disable = true;
                    }
                    projectProxy.macroAlerts($scope.projectNumber, $scope.includeSub, param)
                                      .success(function (data) {
                                          $scope.getAlerts();
                                      });
                }
                //***************************************************************
                $scope.deviceAlertChange = function (element) {
                    element.isChange = true;
                    $scope.showSave = true;
                }
                //************************************************************
                $scope.postAlertsTableData = function () {
                    $scope.ladda.save = true;
                    projectProxy.postAlertsTableData($scope.projectNumber, $scope.tableData)
                                      .success(function (data) {

                                          $scope.showSave = false;
                                          $scope.ladda.save = false;
                                      });
                }
                //*************************************************************
                $scope.getAlerts = function() {
                    projectProxy.getProjectAlerts($scope.projectNumber, $scope.pageFitchers.includeSub, $scope.currentPage, PageSize)
                                       .success(function (data) {
                                           $scope.tableData = data.body;
                                           if ($scope.tableData.totalItems > PageSize) {
                                               $scope.pagerFlag = true;
                                               $scope.connector.CallbackDown($scope.currentPage, PageSize, $scope.tableData.totalItems);
                                           } else {
                                               $scope.pagerFlag = false;
                                           }
                                           $scope.ladda.allow = false;
                                           $scope.ladda.disable = false;
                                           $('#Macro').modal('hide');
                                           
                                       });
                }
                //************************************************************
                $scope.connector.SetCallbackUp(function (pageNumber) {
                    $scope.currentPage = pageNumber;
                    $scope.getAlerts();
                });

                $("#splash-page").css("display", "none");

                closeNavbar();

            }],
            link: function (scope, element, attrs, ngModel) {

              

            }




        };

    }
})(angular);