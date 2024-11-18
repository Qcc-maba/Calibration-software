(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.device')
        .directive('gmapOnline', ['onlineProvider', '$state','siteProxy','coordinator', gmapOnlineFactory]);

    /************************************************************************************************************************************************************************/
    function gmapOnlineFactory(onlineProvider, $state, siteProxy, coordinator) {

    
        var OnlineEvents = ['1000'];
        var map;
        return {
            restrict: 'A',
            transclude: true,
            scope: { location: '=' },
            template: '<div id="map-canvas" style="height: 269px"></div> ',
            replace: true,
            link: function (scope, element, attrs) {

                var marker = { sn: $state.params.deviceId, marker: '' };


                //**************************************Functions**************************

                function onlineDeviceFuncMap(data) {
                    switch (String(data.code)) {
                        case "1000":

                            if (marker.sn == data.sn) {
                                if (!data.connection) {
                                    marker.iconUrl = '/Content/img/grey-dot.png';
                                    marker.marker.setIcon({ url: '/Content/img/grey-dot.png' });
                                }
                                if (data.connection) {
                                    marker.iconUrl = '/Content/img/green-dot.png';
                                    marker.marker.setIcon({ url: '/Content/img/green-dot.png' });
                                }
                                if (data.connection && data.isFailure) {
                                    marker.iconUrl = '/Content/img/green-dot-Alert.png';
                                    marker.marker.setIcon({ url: '/Content/img/green-dot-Alert.png' });
                                }
                                if (data.connection && data.isIrrigating) {
                                    marker.iconUrl = '/Content/img/green-dot-Irrigate.png';
                                    marker.marker.setIcon({ url: '/Content/img/green-dot-Irrigate.png' });
                                }
                                if (data.connection && data.isFertilizing) {

                                    marker.marker.setIcon({ url: '/Content/img/green-dot-Fertilizing.png' });
                                }
                            }
                            break;
                    }
                }


                createMap(scope.location);
                onlineProvider.registerDevice(OnlineEvents, marker.sn, 'deviceMap', onlineDeviceFuncMap);
                //**************************************************************************
                function navigate(location) {
                    // If it's an iPhone..
                    if ((navigator.platform.indexOf("iPhone") != -1)
                        || (navigator.platform.indexOf("iPod") != -1)
                        || (navigator.platform.indexOf("iPad") != -1)) {
                        return "http://maps://maps.google.com/maps?daddr=" + location.lat() + "," + location.lng() + "&amp;ll=";
                    }
                    else {
                        return "http://maps.google.com/maps?daddr=" + location.lat() + "," + location.lng() + "&amp;ll=";
                    }
                };
                //**************************************createMap(Inner)*******************
                function createMap(data) {
                    //coordinator.PublishEvent("SiteLocationChanged", {});
                    var geocoder = geocoder = new google.maps.Geocoder();
                    var mapOptions = {
                        center: new google.maps.LatLng(data.latitude, data.longitude),
                        zoom: 8,
                        mapTypeId: google.maps.MapTypeId.ROADMAP
                    };

                    var map = new google.maps.Map(element[0], mapOptions);

                    var myLatlng = new google.maps.LatLng(data.latitude, data.longitude);
                    marker.marker = new google.maps.Marker({
                        position: myLatlng,
                        map: map,
                        draggable: true,
                        animation: google.maps.Animation.DROP,
                        icon: 'https://maps.google.com/mapfiles/ms/icons/green-dot.png'
                    });

                    google.maps.event.addListener(marker.marker, "dragend", function (e) {
                        var lat, lng, address;
                        geocoder.geocode({ 'latLng': marker.marker.getPosition() }, function (results, status) {
                            if (status == google.maps.GeocoderStatus.OK) {
                                // save new location
                                //SaveSiteDeviceChangeLocation(devices, marker.sn, marker.marker.getPosition().lat(), marker.marker.getPosition().lng());
                                siteProxy.saveDeviceLocation(marker.sn, marker.marker.getPosition().lat(), marker.marker.getPosition().lng())
                                   .success(function (data) {
                                       coordinator.PublishEvent("SiteLocationChanged", {});
                                   });
                                
                            }
                        });

                    });
                    //***************************************************************************
                    google.maps.event.addListener(marker.marker, "click", function (e) {
                        var navigateUrl = navigate(marker.marker.position);
                        var contentString = 
                       '<i class="fa fa-map-marker marginRight7"></i><a href=' + navigateUrl + '>Navigate to device</a>'
                        var infowindow = new google.maps.InfoWindow({
                            content: contentString,
                            maxWidth: 270
                        });
                        infowindow.open(map, marker.marker);

                    });



                }


                //***********************************************************************
            }
        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);