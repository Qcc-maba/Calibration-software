
(function (angular) {
	
    var OnlineEvents = ['1000'];
    angular.module('module.site.preview')
        .directive('mapSite', ['$state', 'baseProxy', 'siteProxy', 'user', 'coordinator', 'translate', 'onlineProvider', 'mainProvider','$rootScope', function ($state, baseProxy, siteProxy, user, coordinator, translate, onlineProvider, mainProvider,$rootScope) {

            function mapCtrl() {
                //$rootScope.isPhone
                //this.MyName = "Vardi";

                this.latlngbounds = null;
                this.markers = [];
                this.map = null;
                this.autoBoundsCenter = null;
                this.siteId = -1;
                this.mapData = null;
            }

            /****************** private functions **********************/
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

            function goToDevice(deviceId, type) {

                $state.go('device', { deviceId: deviceId });
            }

            function createMarkers() {
                this.markers = [];
                var geocoder = geocoder = new google.maps.Geocoder();
                if (this.mapData.location.mode == "roadmap") {
                    this.map.setMapTypeId(google.maps.MapTypeId.ROADMAP);
                } else {
                    this.map.setMapTypeId(google.maps.MapTypeId.HYBRID);
                }

                var _this = this;
                var devices = _this.mapData.devices;
                //****************
                for (var i = 0; i < devices.length; i++) {
                    var myLatlng = new google.maps.LatLng(devices[i].location.latitude, devices[i].location.longitude);
                    devices[i].myLatlng = myLatlng;
                    var marker = new google.maps.Marker({
                        position: myLatlng,
                        map: this.map,
                        ControllerId: devices[i].sn,
                        type: devices[i].deviceType,
                        draggable: devices[i].sharingData.roleModify,
                        device: devices[i],
                        icon: '/Content/img/grey-dot.png',
                        animation: google.maps.Animation.DROP
                    });
                    var pushObject = {
                        markerObject: marker,
                        sn: devices[i].sn
                    }
                    this.markers.push(pushObject);


                    (function (marker) {
                        //get device name
                        google.maps.event.addListener(marker, "click", function (e) {
                            var navigateUrl = navigate(marker.position);
                            var controllerAddress = "/#/device/" + marker.ControllerId;
                            var contentString =
                           '<div class="nevigationWindow">' +
                           '<br/>' +
                           '<h6>Device:</h6>' +
                           '<a href=' + controllerAddress + '>' + marker.ControllerId + '</a>' +
                           '<hr>' +
                           '<i class="fa  fa-key marginRight7"></i><span>' + marker.type.name + '</span><br/>' +
                           '<i class="fa fa-map-marker marginRight7"></i><a href=' + navigateUrl + '>Navigate to device</a>'
                            var infowindow = new google.maps.InfoWindow({
                                content: contentString,
                                maxWidth: 270
                            });
                            infowindow.open(_this.map, marker);

                        });
                        google.maps.event.addListener(_this.map, 'maptypeid_changed', function () {
                            var privilige = user.getSharingData().sharingData;
                            if (privilige.roleModify) {
                                SaveSiteLocation.call(_this);
                            }
                        });
                        google.maps.event.addListener(marker, "dblclick", function (e) {
                            goToDevice.call(this, marker.ControllerId);
                        });
                        var sharingData = user.getSharingData();
                        google.maps.event.addListener(marker, "dragend", function (e) {
                            var lat, lng, address;
                            geocoder.geocode({ 'latLng': marker.getPosition() }, function (results, status) {
                                if (status == google.maps.GeocoderStatus.OK) {

                                    marker.device.myLatlng = new google.maps.LatLng(marker.getPosition().lat(), marker.getPosition().lng());
                                    SaveSiteDeviceChangeLocation.call(_this, marker.ControllerId, marker.getPosition().lat(), marker.getPosition().lng());
                                    for (var i = 0; i < devices.length; i++) {
                                        if (marker.ControllerId == devices[i].sn) {
                                            devices[i].location.latitude = marker.getPosition().lat();
                                            devices[i].location.longitude = marker.getPosition().lng();
                                            devices[i].myLatlng = new google.maps.LatLng(marker.getPosition().lat(), marker.getPosition().lng());
                                        }
                                        break;
                                    }
                                    calculateSiteLocation.call(_this);
                                }
                            });

                        });

                    })(marker);


                }
                calculateSiteLocation.call(this);
                fixLoadingOff();

            }

            function onlineCBfuncMap(data) {

                var markersLen = this.markers.length;
                switch (String(data.code)) {
                    case "1000":
                        for (var i = 0; i < markersLen; i++) {
                            if (this.markers[i].sn == data.sn) {
                                //this.markers[i].data = data;
                                if (!data.connection) {
                                    this.markers[i].iconUrl = '/Content/img/grey-dot.png';
                                    this.markers[i].markerObject.setIcon({ url: '/Content/img/grey-dot.png' });
                                }
                                if (data.connection) {
                                    this.markers[i].iconUrl = '/Content/img/green-dot.png';
                                    this.markers[i].markerObject.setIcon({ url: '/Content/img/green-dot.png' });
                                }
                                if (data.connection && data.isFailure) {
                                    this.markers[i].iconUrl = '/Content/img/green-dot-Alert.png';
                                    this.markers[i].markerObject.setIcon({ url: '/Content/img/green-dot-Alert.png' });
                                }
                                if (data.connection && data.isIrrigating) {
                                    this.markers[i].iconUrl = '/Content/img/green-dot-Irrigate.png';
                                    this.markers[i].markerObject.setIcon({ url: '/Content/img/green-dot-Irrigate.png' });
                                }
                                if (data.connection && data.isFertilizing) {
                                    this.markers[i].iconUrl = '/Content/img/green-dot-Fertilizing.png';
                                    this.markers[i].markerObject.setIcon({ url: '/Content/img/green-dot-Fertilizing.png' });
                                }



                            }
                        }
                        break
                }
            }

            function showPosition(position) {
                this.map.setCenter({ lat: position.coords.latitude, lng: position.coords.longitude });// get current location
            }

            function calculateSiteLocation() {

                var devices = this.mapData.devices;

                if (devices.length == 0) {
                    getLocation.call(this);
                } else {
                    this.latlngbounds = new google.maps.LatLngBounds();
                    for (var i = 0; i < devices.length; i++) {
                        this.latlngbounds.extend(devices[i].myLatlng);
                    }
                    this.autoBoundsCenter = this.latlngbounds.getCenter();
                    this.map.setCenter(this.autoBoundsCenter);
                    this.map.fitBounds(this.latlngbounds);

                    SaveSiteLocation.call(this);

                    var siteLocCenter = {
                        lat: this.autoBoundsCenter.lat(),
                        lan: this.autoBoundsCenter.lng()
                    }
                    broadcastMapLocationChanged.call(this, siteLocCenter);


                }
            }

            function SaveSiteDeviceChangeLocation(deviceId, deviceLat, deviceLan) {
                var _this = this;
                siteProxy.SaveSiteDeviceChangeLocation(this.siteId, deviceId, deviceLat, deviceLan)
                      .success(function (data) {
                          toastr.success('Device Change Location Saved', 'Success!');
                          calculateSiteLocation.call(_this);

                      });
            }

            function broadcastMapLocationChanged(siteCenter) {
                coordinator.PublishEvent("SiteLocationChanged", siteCenter);
            }

            function SaveSiteLocation() {

                var typeMap = this.map.getMapTypeId();
                this.zoomLevel = this.map.getZoom();
                this.center = this.map.getCenter();

                siteProxy.SaveSiteLocation(this.siteId, this.zoomLevel, this.center.lat(), this.center.lng(), typeMap, this.UseAutoBounds)
                      .success(function (data) {

                      });
            }

            function getLocation() {    // if no devices 
                this.map.setZoom(16);
                var _this = this;
                if (navigator.geolocation) {
                    navigator.geolocation.getCurrentPosition(function () {
                        showPosition.apply(_this, arguments);
                    });
                } else {
                    this.map.setCenter({ lat: 32.4, lng: 33.8 }); // if gps not allowd
                }
            }

            /****************** public Object function **********************/
            mapCtrl.prototype.ReloadSiteMap = function (siteId) {
                this.siteId = siteId;
                var _this = this;

                var privilige = user.getSharingData().sharingData;

                siteProxy.GetControllersLocation(this.siteId)
                   .success(function (data) {
                       _this.mapData = data.body;
                       createMarkers.call(_this);
                       onlineProvider.registerSite(OnlineEvents, _this.siteId, 'siteMap', function () {
                           onlineCBfuncMap.apply(_this, arguments);
                       });
                   });
            }

            mapCtrl.prototype.AutoBound = function () {

                calculateSiteLocation.call(this);
                this.map.setCenter(this.autoBoundsCenter);
                this.map.fitBounds(this.latlngbounds);
            }

            mapCtrl.prototype.setMap = function (map) {

                this.map = map;
            }






            return {
                restrict: 'EA',
                require: ['?ngModel', 'mapSite'],
                transclude: true,
                template: '<div><div data-title></div><div id="map-canvas-site" data-map>Please wait.. loading map..</div></div> ',
                replace: true,
                controller: mapCtrl,
                controllerAs: 'vm',
                bindToController: true,
                link: function (scope, element, attrs, controllers) {

                    var mapCtrl = controllers[1];
                    var ngModel = controllers[0];
                    var mapCreated = false;

                    if (!ngModel) return; // do nothing if no ng-model
                    ngModel.$render = function () {
                        var siteId = ngModel.$viewValue;

                        if (!mapCreated) {
                            createMap();
                        }
                        mapCtrl.ReloadSiteMap(siteId);
                    };


                    function useAutomaticBounds(map, autoBoundCallback) {

                        var AutomaticBounds = document.createElement('div');

                        var AutoUI = document.createElement('div');
                        AutoUI.style.backgroundColor = '#fff';
                        AutoUI.style.border = '2px solid #fff';
                        AutoUI.style.borderRadius = '3px';
                        AutoUI.style.boxShadow = '0 2px 6px rgba(0,0,0,.3)';
                        AutoUI.style.cursor = 'pointer';
                        AutoUI.style.marginBottom = '5px';
                        AutoUI.style.width = '60px';
                        AutoUI.style.height = '34px';
                        AutoUI.style.margin = '7px 7px 0px 0px';
                        AutomaticBounds.appendChild(AutoUI);

                        var controlText = document.createElement('div');
                        controlText.style.color = 'rgb(25,25,25)';
                        controlText.style.fontFamily = 'Roboto,Arial,sans-serif';
                        controlText.style.fontSize = '14px';
                        controlText.style.lineHeight = '28px';
                        controlText.style.paddingLeft = '5px';
                        controlText.style.paddingRight = '5px';
                        controlText.style.width = '60px';
                        controlText.style.height = '34px';
                        controlText.innerHTML = 'Center';

                        AutoUI.appendChild(controlText);

                        google.maps.event.addDomListener(AutoUI, 'click', function () { //auto bounds
                            autoBoundCallback();
                        });

                        AutomaticBounds.index = 1;
                        map.controls[google.maps.ControlPosition.RIGHT_TOP].push(AutomaticBounds);
                    }

                    function createMap() {
                        var mapOptions = {
                            //center: new google.maps.LatLng(centerLat, centerLn),
                            zoom: 8,
                            mapTypeId: google.maps.MapTypeId.ROADMAP,
                            draggable: $rootScope.isPhone?false:true
                        };

                        var mapDiv = $(element).find("div[data-map='']")[0];
                        var map = new google.maps.Map(mapDiv, mapOptions);


                        mapCtrl.setMap(map);

                        useAutomaticBounds(map, function () {
                            mapCtrl.AutoBound();
                        });

                        mapCreated = true;
                    }


                }
            };



        }]);
   
   
})(angular);





