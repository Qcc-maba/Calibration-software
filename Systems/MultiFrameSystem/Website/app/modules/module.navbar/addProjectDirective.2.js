
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.menuNavigation')
        .directive('addProject', addProjectFactory);
    /************************************************************************************************************************************************************************/
    function addProjectFactory() {
        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.navbar/addProject.html',
            controller: ['$scope', '$filter', 'projectProxy', '$state', 'mainRouter', function ($scope, $filter, projectProxy, $state, mainRouter) {

                //************************************************Attributs*******************
                $scope.ProjectName = "";
                $scope.ladda = {
                    'addProject':false
                }
                //************************************************functions*******************
                //***********************showPosition(Inner)****************
                function showPosition(position) {
                    $scope.centerLat = position.coords.latitude;
                    $scope.centerLng = position.coords.longitude;
                }
                //***********************getLocation(Inner)****************
                function getLocation() {
                    if (navigator.geolocation) {
                        navigator.geolocation.getCurrentPosition(showPosition);
                    } else {
                        toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                        //California, United States
                        $scope.centerLat = 36.542750;
                        $scope.centerLng = -119.800532;
                    }
                }
                //***********************saveNewProject(Outer)****************
                $scope.saveNewProject = function (func, addProjectform) {
                    if (addProjectform) {
                        $scope.ladda.addProject = true;
                        projectProxy.saveNewProject($scope.ProjectName, $scope.centerLat, $scope.centerLng)
                         .success(function (data) {
                             toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                           
                             $state.go('site.preview.map', ({ siteId: data.body.projectID }));
                             mainRouter.callkey("tree", data.body.projectID);
                             $scope.ladda.addProject = false;
                             $scope.ProjectName = "";
                             $('#addProject').modal('hide');
                         }).error(function (data, status, headers, config) {
                             toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                         });
                    } else {
                        toastr.error($filter('translate')('toastrErrForms'), $filter('translate')('Error'));
                    }
                }
                //************************************************
                $scope.resetModal = function (form) {
                    form.$rollbackViewValue();
                    form.$setPristine(); //Set pristine state
                    form.$setUntouched(); //Set state from touched to untouched
                    $scope.ProjectName = "";
                }
                getLocation();


            },
        ]};
    }
})(angular);






