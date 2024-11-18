(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.weather.forecast')
        .directive('oneday', onedayFactory);
    function onedayFactory() {
        return {
            restrict: 'A',
            scope: {
                onedayweather:'='
            },
            templateUrl: 'app/modules/module.weather/foreCast/oneday.html',
            controller: ['$scope', '$locale', 'user', function ($scope, $locale, user) {
                $scope.locale = $locale;
                //$scope.tempUnitID = user.getUser().info.tempUnitID;
                function buildDayHover() {
                    $scope.oneDay = {
                        dayDes: '',
                        temperature: '',
                        humidity: '',
                        prec: '',
                        unitLabel: $scope.onedayweather.temperature.unitLabel

                    };
                    switch ($scope.onedayweather.temperature.valueType) {
                        case 'AvgOnly':
                            $scope.oneDay.temperature = $scope.onedayweather.temperature.avg;
                            $scope.oneDay.dayDes = 'Day Temperature :' + $scope.oneDay.temperature + '°';
                            break;
                        case 'MaxOnly':
                            $scope.oneDay.temperature = $scope.onedayweather.temperature.high;
                            $scope.oneDay.dayDes = 'Day Temperature :' + $scope.oneDay.temperature + '°';
                            break;
                        case 'MinOnly':
                            $scope.oneDay.temperature = $scope.onedayweather.temperature.low;
                            $scope.oneDay.dayDes = 'Night Temperature :' + $scope.oneDay.temperature + '°';
                            break;
                        case 'All':
                            $scope.oneDay.temperature = $scope.onedayweather.temperature.high;
                            $scope.oneDay.dayDes = 'Day Temperature :' + $scope.oneDay.temperature + '°';
                            $scope.oneDay.dayDes = ' / ';
                            $scope.oneDay.temperature = $scope.onedayweather.temperature.low;
                            $scope.oneDay.dayDes = 'Night Temperature :' + $scope.oneDay.temperature + '°';
                            break;
                    }
                    $scope.oneDay.temperature + $scope.onedayweather.temperature.temperatureUnitLabel + '°';


                    switch ($scope.onedayweather.humidity.valueType) {
                        case 'AvgOnly':
                            $scope.oneDay.humidity = $scope.onedayweather.humidity.avg 
                            break;
                        case 'MaxOnly':
                            $scope.oneDay.humidity = $scope.onedayweather.humidity.high 
                            break;
                        case 'MinOnly':
                            $scope.oneDay.humidity = $scope.onedayweather.humidity.low 
                
                            break;
                        case 'All':
                            $scope.oneDay.humidity = $scope.onedayweather.humidity.high 
                         
                            break;
                    }

                    switch ($scope.onedayweather.prec_PercentChance.valueType) {
                        case 'AvgOnly':
                            $scope.oneDay.prec = $scope.onedayweather.prec_PercentChance.avg 
            
                            break;
                        case 'MaxOnly':
                            $scope.oneDay.prec = $scope.onedayweather.prec_PercentChance.day 
     
                            break;
                        case 'MinOnly':
                            $scope.oneDay.prec = $scope.onedayweather.prec_PercentChance.night 

                            break;
                        case 'All':
                            $scope.oneDay.prec = $scope.onedayweather.prec_PercentChance.day 
                
                            break;
                    }
                   
                    
                }

                //****************
                buildDayHover();
            }
        ]};              
    }
})(angular);
