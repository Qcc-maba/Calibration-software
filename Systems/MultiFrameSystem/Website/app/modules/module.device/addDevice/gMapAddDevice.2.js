(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.device')
    .directive('googleplace', function ($timeout, directiveComm) {

        return {
            require: 'ngModel',
            scope: {
                comm: '=',
                item: '='
            },
            link: function (scope, element, attrs, model) {
                var center = {
                    lat: -33.8688,
                    lan: 151.2195
                }
                if (scope.item.latitude != "" && scope.item.longitude != "") {
                    center.lat = scope.item.latitude;
                    center.lan = scope.item.longitude;

                }
                var map = new google.maps.Map(document.getElementById(attrs.googleplace), {

                    center: { lat: center.lat, lng: center.lan },
                    zoom: 17
                });
                var infowindow = new google.maps.InfoWindow();
                var marker = new google.maps.Marker({
                    draggable: true,
                    map: map,
                    anchorPoint: new google.maps.Point(0, -29)
                });
                var myLatlng = new google.maps.LatLng(center.lat, center.lan);

                var options = {
                    types: [],
                    componentRestrictions: {}
                };

                marker.setPosition(myLatlng);
                marker.setVisible(true);
                scope.gPlace = new google.maps.places.Autocomplete(element[0], options);
                google.maps.event.addDomListener(element[0], 'keydown', function (e) {
                    if (e.keyCode === 13) {
                     
                            e.preventDefault();
                            e.stopPropagation();
                 
                    } else {
                 
                    }
                });
                google.maps.event.addListener(scope.gPlace, 'place_changed', function (e) {
                  
                    infowindow.close();
                    marker.setVisible(false);
                    var place = scope.gPlace.getPlace();
                    scope.comm.CallbackUp(place.geometry.location);


                    if (!place.geometry) {
                        window.alert("Autocomplete's returned place contains no geometry");
                        return;
                    }

                    // If the place has a geometry, then present it on a map.
                    if (place.geometry.viewport) {
                        map.fitBounds(place.geometry.viewport);
                    } else {
                        map.setCenter(place.geometry.location);
                        map.setZoom(20);  // Why 17? Because it looks good.

                   }
                    marker.setPosition(place.geometry.location);
                    marker.setVisible(true);

                  
                });
                //*****************
                google.maps.event.addListener(marker, "dragend", function (e) {
                    scope.comm.CallbackUp(marker.getPosition());
                    map.setCenter(marker.getPosition());

                });

                $timeout(function () {
                    var predictionContainer = angular.element(document.getElementsByClassName('pac-container'));
                    predictionContainer.attr('data-tap-disabled', true);
                    predictionContainer.css('pointer-events', 'auto');
                    predictionContainer.bind('click', function (arg) {
                        element[0].blur();
                    });
                    console.log('timout', predictionContainer)
                }, 500);

            }
        };
    })
})(angular);