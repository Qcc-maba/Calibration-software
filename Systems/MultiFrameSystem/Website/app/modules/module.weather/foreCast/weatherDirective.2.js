(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.weather.forecast')
        .directive('weatherDirective', weatherDirectiveFactory);
    /**********************************************************************************************************************************************************************/
    function weatherDirectiveFactory() {

        return {
            restrict: 'EA',
            require: '?ngModel',
            templateUrl: 'app/modules/module.weather/foreCast/weather.html',
            controller: ['$scope', '$http', '$stateParams', 'baseProxy', 'siteProxy', 'weatherProxy', '$filter', 'coordinator', 'translate','user', function ($scope, $http, $stateParams, baseProxy, siteProxy, weatherProxy, $filter, coordinator, translate,user) {
                //*********************************************Attribute****************
                $scope.bigView = false;
                $scope.AdvanceSettings = false;
                $scope.ladda = {
                    'saveWeather':false
                }
                $scope.siteAdd = {
                    siteName:""
                }
                $scope.applyHierarchy={val:false};
                $scope.yyy = true;
                $scope.tempUnitID = user.getUser().info.tempUnitID;
                var dt = new Date();
                var secs = dt.getSeconds() + (60 * dt.getMinutes()) + (60 * 60 * dt.getHours());

                //********************************************Functions******************
                //*********************************************coordinator.SubscribeEvent**************************
                coordinator.SubscribeEvent("SiteLocationChanged", function (event) {
                    //var location = {
                    //    lat: event.lat,
                    //    lan: event.lan
                    //} 
                    $scope.GetWeatherDetails($scope.isDevice);
                });
                //*********************************************getAddress(Inner)**************************
                function getAddress(data) {
                    var lat = data.body.location.lat.toString();
                    var lan = data.body.location.lon.toString();
                  
                    var latlng = new google.maps.LatLng(lat, lan);
                    var geocoder = geocoder = new google.maps.Geocoder();
                    geocoder.geocode({ 'latLng': latlng }, function (results, status) {
                        if (status == google.maps.GeocoderStatus.OK) {
                            if (results[1]) {
                                $scope.siteAdd.siteName = results[1].formatted_address;
                                $scope.$apply();
                            }
                        } else {
                            $scope.siteAdd.siteName = lat + ", " + lan;
                            $scope.$apply();
                        }
                    });
                }
                //***************************************************************************************
                function chooseIcon(days) {
                    for (var i = 0; i < days.length; i++) {
                        if(secs < 72000){
                            days[i].skyIconURL = days[i].iconData.day_Url;
                        } else {
                            days[i].skyIconURL = days[i].iconData.night_Url;
                        }
                    }
                }
                //*********************************************GetWeatherDetails(Inner)*******************
                $scope.GetWeatherDetails = function(isDevice) {
                    var localTime = new Date();
                    var GmtAbs = localTime.getTimezoneOffset() * 60 * 1000;
                    ///*********************************************992 just for gsi temporery
                    if (isDevice) {
                        var id = $stateParams.deviceId;
                        
                    } else {
                        var id = $stateParams.siteId;
                    }
                    
                    weatherProxy.GetWeatherDetails(id, localTime.getTime() - GmtAbs, isDevice)
                   .success(function (data) {
                       $scope.date = $filter('date')(localTime.getTime() - GmtAbs, 'mediumDate', 'UTC');
                       while (data.body.forecastsData.length>5) {
                           data.body.forecastsData.pop();
                       }
                       $scope.days = data.body.forecastsData
                       chooseIcon($scope.days);
                       if (!isDevice) {
                           weatherProxy.GetWeatherSettings(id)
                                 .success(function (data) {
                                     $scope.Savings = data.body.saving || 17;
                                     $scope.Settings = data.body;
                                     $scope.privilige = user.getSharingData().sharingData.roleModify;

                                 });
                       }
                       getAddress(data)
                      
                   });
                }
 
                //*********************************************toggleAdvanceSettings(Outer)*******************
                $scope.toggleAdvanceSettings = function () {
                    $scope.AdvanceSettings = !$scope.AdvanceSettings;
                }
                //*********************************************saveDetails(Outer)*******************
                $scope.saveDetails = function (func,valid) {


                    if (valid) {
                        $scope.validation = false;
                        $scope.ladda.saveWeather = true;
                        var siteId = $stateParams.siteId;
                        weatherProxy.SaveWeatherSettings(siteId, $scope.Settings, $scope.applyHierarchy.val)
                         .success(function (data, status, headers, config) {
                             $scope.ladda.saveWeather = false;
                             toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                             func();
                         })
                         .error(function (data, status, headers, config) {
                             toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
                             $scope.ladda.saveWeather = false;
                             func();
                         });
                    } else {
                        toastr.error($filter('translate')('toastrErrForms'), $filter('translate')('Error'));
                    }
                }
                //*************************************************************************************
                $scope.showBigView = function () {
                    $scope.bigView = true;
                }
      
            }
            ],
            link: function (scope, element, attrs, ngModel) {
                scope.isDevice = attrs.param == 'device';
                scope.GetWeatherDetails(scope.isDevice);
            }


        };
    }
    /*******************************************************************************************************************************************************************************/

})(angular);






