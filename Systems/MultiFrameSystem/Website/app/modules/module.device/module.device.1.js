angular.module("module.device", [
     "ui.router"
 ])
.config(['$stateProvider', function ($stateProvider) {
    $stateProvider
    .state('device', {
        url: '/device/:deviceId',
        views: {
            'root@': {
                templateUrl: 'app/modules/module.device/device.html',
                controller: ['$scope', '$stateParams', '$state', 'siteProxy', '$filter', 'mainProvider', 'user', 'mainRouter', 'coordinator', function ($scope, $stateParams, $state, siteProxy, $filter, mainProvider, user, mainRouter, coordinator) {
                    $('#dragbar').css("display", "none");
                   
                   
                    //*******************************************************
                    siteProxy.GetDeviceInfo($stateParams.deviceId)
                        .success(function (data) {
                            $scope.device = data.body;
                            mainProvider.CurrentSite.data.siteId = $scope.device.parentSiteInfo.siteID;
                            user.saveSharingData(-1, $scope.device.parentSiteInfo.sharedView);
                           $scope.privilige = user.getSharingData().sharingData;
                           $scope.deviceIndex = findCurrentDeviceIndexInArray($scope.device.otherDevicesView);
                       
                           switch (mainProvider.CurrentDevice.data.deviceType.name) {

                               case "GSI":
                                   $state.go('device.GSI_device.status', { deviceId: mainProvider.CurrentDevice.data.sn });

                                   break;
                               case "GSI-AG":
                                   $state.go('device.GSI_device.status', { deviceId: mainProvider.CurrentDevice.data.sn });

                                   break;
                               case "XCI-WIFI":
                                   if ($state.current.name == 'device.XCI_device.view') {
                                       $state.go('device.XCI_device.view', { deviceId: mainProvider.CurrentDevice.data.sn });
                                   } else {
                                       $state.go('device.XCI_device.online', { deviceId: mainProvider.CurrentDevice.data.sn });
                                   }
                               

                                   break;
                               case "XCI":
                                   if ($state.current.name == 'device.XCI_device.view') {
                                       $state.go('device.XCI_device.view', { deviceId: mainProvider.CurrentDevice.data.sn });
                                   } else {
                                       $state.go('device.XCI_device.online', { deviceId: mainProvider.CurrentDevice.data.sn });
                                   }

                                   break;
                           }
                        }).error(function (data, status, headers, config) {
                            toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
                        });
                    //************************************************************
                    findCurrentDeviceIndexInArray = function (list) {
                        for (var i = 0; i < list.length; i++) {
                            if (list[i].sn == $stateParams.deviceId) {
                                mainProvider.CurrentDevice.data = list[i];
                                $scope.currentDevice = list[i];
                                if (i == 0) {
                                    $scope.nextPrev = {
                                        nextShow: true,
                                        prevShow: false
                                    }
                                }
                                else if (i == list.length-1) {
                                    $scope.nextPrev = {
                                        nextShow: false,
                                        prevShow: true
                                    }
                                }
                                else {
                                    $scope.nextPrev = {
                                        nextShow: true,
                                        prevShow: true
                                    }
                                }
                                return i;
                            }
                        }
                        return null
                    }


                    $scope.prev = function () {
                        if ($scope.deviceIndex > 0) {
                            mainProvider.goToSite = false;
                            $state.go('device', { deviceId: $scope.device.otherDevicesView[$scope.deviceIndex - 1].sn });
                        } else {
                            
                        }
                    }
                    $scope.next = function () {
                        if ($scope.deviceIndex < $scope.device.otherDevicesView.length - 1) {
                            mainProvider.goToSite = false;
                            $state.go('device', { deviceId: $scope.device.otherDevicesView[$scope.deviceIndex + 1].sn });
                        }
                    }


                    $scope.goToSite = function (id) {
                        
                        $state.go('site.preview.map', { siteId: id });
                        mainRouter.callkey("tree", id);
                    }


                    $("#splash-page").css("display", "none");

                    closeNavbar();
                }
                ]
            }
        }
    })
   

}]);