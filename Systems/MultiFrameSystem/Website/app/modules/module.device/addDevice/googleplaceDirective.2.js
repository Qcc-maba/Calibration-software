
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.device')
        .directive('googleplace', googleplaceFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function googleplaceFactory() {
        return {
            restrict: 'EA',
            controller:['$scope','$filter','deviceProxy', function ($scope, $filter, deviceProxy) {
                //******************************Attributs****************************************
                $scope.observes = true;

                //*****************************Function******************************************
                //*****************************showPosition(Inner)******************************************
                function showPosition (position) {
                    var obj = {};
                    obj.lat = position.coords.latitude;
                    obj.lan = position.coords.longitude;
                    $scope.$broadcast('addDeviceMapEvent', { mapData: obj });
                    $scope.$emit('deviceGeoLocation', obj);
                }
                //*****************************getLocation(Outer)******************************************
                $scope.getLocation = function () {
                    if (navigator.geolocation) {
                        navigator.geolocation.getCurrentPosition(showPosition);
                    } else {
                        toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
                        //California, United States
                        obj.lat = 36.542750;
                        obj.lan = -119.800532;
                        $scope.$broadcast('addDeviceMapEvent', { mapData: obj });
                        $scope.$emit('deviceGeoLocation', obj);
                    }
                }
                //*****************************chooseLocation(Outer)******************************************
                $scope.chooseLocation = function (add) {
                    if(add!=''){
                    $scope.add = add;
                    $scope.ctrlLocation = add;
                    deviceProxy.GetCoordinate(add)
                   .success(function (data) {
                       var obj = {};
                       obj.lat = data.results[0].geometry.location.lat;
                       obj.lan = data.results[0].geometry.location.lng;
                       $scope.$broadcast('addDeviceMapEvent', { mapData: obj });
                       $scope.$emit('deviceGeoLocation', obj);
                   });
                    }
                }
            }],
            link: function (scope, element, attrs) {
            
                var autocomplete = new google.maps.places.Autocomplete(element[0], { types: ['geocode'] });
                var options = {
                    types: [],

                };
                scope.getLocation();
                $(element).blur(function (e) {
                    window.setTimeout(function () {
                        angular.element(element).trigger('input');
                        scope.chooseLocation(element[0].value);
                    }, 0);
                });
            }
        }
    }
})(angular);






