(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.message')
        .directive('gmap1', gmapFactory);

    /************************************************************************************************************************************************************************/
    function gmapFactory() {

        return {
            restrict: 'A',
            require: '?ngModel',
            transclude: true,



            template: '<div id="map-canvas-transfer" style="height: 300px"></div> ',
         
            replace: true,
       
            link: function (scope, element, attrs, ngModel) {
         
                scope.createMap = function (lat ,lan,zoom) {




                    var markers = [];
           
                            var obj = {};
                            obj.lat = lat;
                            obj.lng = lan;
                            markers.push(obj);
                 

                    var mapOptions = {
                        center: new google.maps.LatLng(lat, lan),
                        zoom: zoom,
                        mapTypeId: google.maps.MapTypeId.ROADMAP

                    };
            
                    var map = new google.maps.Map(element[0], mapOptions);

                    for (var i = 0; i < markers.length; i++) {
                        var data1 = markers[i]
                        var myLatlng = new google.maps.LatLng(data1.lat, data1.lng);
                        var marker = new google.maps.Marker({
                            position: myLatlng,
                            map: map,
                            siteId: data1.siteId,
                            draggable: false,
                            animation: google.maps.Animation.DROP
                        });
                       
                       
                      
                    }

          
                }
                ngModel.$render = function () {

                    var lan = parseFloat(attrs.lan);
                    var zoom = parseFloat(attrs.zoom);
                    scope.createMap(ngModel.$viewValue, lan, zoom);
                };
            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);