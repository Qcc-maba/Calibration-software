
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site')
        .directive('addSite', ['$filter', addSiteDFactory]);
    /***********************************************************************************************************************************************************************/
    function addSiteDFactory($filter) {
        return {
            restrict: 'EA',
            require: '?ngModel',
            templateUrl: 'app/modules/module.site/addSite.html',

            controller: ['$scope','$rootScope', 'siteProxy', '$filter', '$state','mainRouter','mainProvider',
            function ($scope, $rootScope, siteProxy, $filter, $state, mainRouter,mainProvider) {
                    //************************************************attributs*******************
                const MAX_SITE_LEVEL = 5;
                $scope.isAddSite = true;
                $scope.siteName = "";
                    $scope.addSiteLadda = false;
                    //************************************************functions*******************
                    //***********************showPosition(Outer)****************
                    $scope.saveNewSite = function (func, addsiteform) {


                        if (mainProvider.CurrentSite.data.level > MAX_SITE_LEVEL) {
                            $scope.isAddSite = false;
                        }else{ 
                            if (addsiteform) {
                                $scope.addSiteLadda = true;
                                siteProxy.CreateNewSite($scope.ProjectId, $scope.siteName)
                                 .success(function (data) {
                                     func();
                                     $scope.addSiteLadda = false;
                                     var obj = {};
                                     obj.projectID = $scope.ProjectId;
                                     obj.siteID = data.body;
                                     obj.name = $scope.siteName;
                                     obj.sharingData = {
                                         hasRole_Control: true,
                                         hasRole_Modify: true,
                                         hasRole_View: true,
                                         isPending: false
                                     }
                                     $scope.siteName = "";
                                     $state.go('site.preview.map', { siteId: data.body });
                                     mainRouter.callkey("tree", data.body);
                          
                                 });
                            } else {
                                toastr.error('Form Errors', 'Error!');
                            }
                        }
                        
                    }
                    //*********************************************************
                    $scope.resetModal = function (form) {
                        form.$rollbackViewValue();
                        form.$setPristine(); //Set pristine state
                        form.$setUntouched(); //Set state from touched to untouched
                    }


                }],
            link: function (scope, element, attrs, ngModel) {

                if (!ngModel) return;
                ngModel.$render = function () {

                    scope.ProjectId = ngModel.$viewValue;
                    scope.ProjectName = attrs.pname;

                };

            }

        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);






