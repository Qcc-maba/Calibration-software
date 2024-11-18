(function (angular) {
    'use strict';
angular.module('module.weather.forecast')
  .filter('precipitation', function () {
      return function (input) {
          switch (input) {
              case "Inch":
                  return "in";
              
              case "mm":
                  return "mm";

              case "Percent":
                  return "%"
          }
      };
  });

})(angular);