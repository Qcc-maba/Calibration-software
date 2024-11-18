(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.device')
        .directive('setTime', setTimeFactory);
    /*******************************************************************************************************************************************************************/
    function setTimeFactory() {

        return {
            restrict: 'A',
            scope: {
                callback: "&",
            },
            templateUrl: 'app/modules/module.device/setTime/setOnlineTime.html',
            controller: ['$scope', '$filter', function ($scope, $filter) {
                //************************************Attribute**********************************
                $scope.time = {
                    "Hours": 0,
                    "Minutes": 1,
                    "Seconds": 0
                }
                //************************************addHours**********************************
                $scope.addHours = function () {
                    if ($scope.time.Hours < 99) {
                        $scope.time.Hours++;
                    } else {
                        $scope.time.Hours = 0;
                    }
                }
                //************************************subHours**********************************
                $scope.subHours = function () {
                    if ($scope.time.Hours > 0) {
                        $scope.time.Hours--;
                    }
                }
                //************************************addMinutes**********************************
                $scope.addMinutes = function () {
                    if ($scope.time.Minutes < 59) {
                        $scope.time.Minutes++;
                    } else {
                        $scope.time.Minutes = 0;
                    }
                }
                //************************************subMinutes**********************************
                $scope.subMinutes = function () {
                    if ($scope.time.Minutes > 0) {
                        $scope.time.Minutes--;
                    } else {
                        $scope.time.Minutes = 59;
                    }
                }
                //************************************addMinutes**********************************
                $scope.addSeconds = function () {
                    if ($scope.time.Seconds < 59) {
                        $scope.time.Seconds++;
                    } else {
                        $scope.time.Seconds = 0;
                 
                    }
                }
                //************************************subMinutes**********************************
                $scope.subSeconds = function () {
                    if ($scope.time.Seconds > 0) {
                        $scope.time.Seconds--;
                    } else {
                        $scope.time.Seconds = 59;
                    }
                }
                //********************************************************************************
                $scope.save = function (form) {
                    if (form) {
                        $scope.callback()($scope.time,null);
                    } else {
                        toastr.error($filter('translate')('toastrErrForms'), $filter('translate')('Error'));
                    }
                    
                }
                //*******************************************************************************
                $scope.closeModal = function (form) {
                    $scope.time = {
                        "Hours": 0,
                        "Minutes": 1,
                        "Seconds": 0
                    }
                    form.$rollbackViewValue();
                    form.$setPristine(); //Set pristine state
                    form.$setUntouched(); //Set state from touched to untouched
                }
               

            }],
            link: function (scope, element, attrs) {
            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);