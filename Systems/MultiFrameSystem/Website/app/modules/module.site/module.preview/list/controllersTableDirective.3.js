
(function (angular) {

    var module = angular.module('module.site.preview');

    var OnlineEvents = ['1000'];


    module.directive('siteConT', ['$http', '$filter', '$stateParams', '$state', 'siteProxy', 'deviceProxy', 'user', 'mainProvider', 'onlineProvider', function ($http, $filter, $stateParams, $state, siteProxy, deviceProxy, user, mainProvider, onlineProvider) {

        function ListCtrl() {
            var myVars = {
                x: 4
            };

            this.getX = function () {
                return myVars;
            }
            this.deviceSn = null;
           
            this.alerts = null;
            this.controllers = null;
            this.start = null;
            this.laddaAlerts = null;
        }
        /****************** private functions **********************/
        function onlineCBfuncDEviceList(data) {
            switch (String(data.code)) {
                case "1000":
                    for (var i = 0; i < this.controllers.length; i++) {
                        if (this.controllers[i].sn == data.sn) {

                            if (!data.connection) {
                                this.controllers[i].icon = '/Content/img/grey-dot.png';
                            }
                            if (data.connection) {
                                this.controllers[i].icon = '/Content/img/green-dot.png';
                            }
                            if (data.connection && data.isFailure) {

                                this.controllers[i].icon = '/Content/img/green-dot-Alert.png';
                            }
                            if (data.connection && data.isIrrigating) {

                                this.controllers[i].icon = '/Content/img/green-dot-Irrigate.png';
                            }
                            if (data.connection && data.isFertilizing) {

                                this.controllers[i].icon = '/Content/img/green-dot-Fertilizing.png';
                            }
                        }
                    }
                    break;
            }
        }
        /****************** public Object function **********************/
        ListCtrl.prototype.GetsiteConT = function (siteID) {
            var _this = this;

            this.getX().x;
            
            siteProxy.GetsiteConT(siteID)
               .success(function (data) {

                   _this.controllers = data.body;
                   for (var i = 0; i < _this.controllers.length; i++) {
                       _this.controllers[i].icon = '/Content/img/grey-dot.png';

                   }
                   _this.start = true;
                   fixLoadingOff();
                   onlineProvider.registerSite(OnlineEvents, siteID, 'siteList', function(){
                       onlineCBfuncDEviceList.apply(_this, arguments);
                   });

               }).error(function (data, status, headers, config) {
                   toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
                   fixLoadingOff();
               });
        }
        ListCtrl.prototype.openAddAlerts = function (param) {
            var _this = this;
            deviceProxy.openAddAlerts(param)
                .success(function (data) {
                    _this.deviceSn = param;
                    _this.alerts = data.body;
                });
        }
        ListCtrl.prototype.switchDeviceAlerts = function (isAlert) {
            var _this = this;
            isAlert.tb.isAlertsEnabled = !isAlert.tb.isAlertsEnabled;
            siteProxy.switchDeviceAlerts(isAlert.tb.sn, isAlert.tb.isAlertsEnabled)
            .success(function (data, status, headers, config) {
                toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
            }).error(function (data, status, headers, config) {
                toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
            });
        }
        ListCtrl.prototype.saveAlerts = function (func) {
            var _this = this;
            this.laddaAlerts = true;
            deviceProxy.CtrlAlertsSavings($scope.deviceSn, $scope.alerts)
                .success(function (data, status, headers, config) {
                    toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                    _this.laddaAlerts = false;
                    func();
                })
                .error(function (data, status, headers, config) {
                    toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
                });
        }
        ListCtrl.prototype.goToDevice = function (sn) {
            $state.go('device', { deviceId: sn });
        }

        return {
            restrict: 'EA',
            require: ["siteConT"],
            templateUrl: 'app/modules/module.site/module.preview/list/listDirectiveTemplate.html',
            controller: ListCtrl,//'ListCtrl as vm',
            controllerAs: 'vm',
            bindToController: true,
            link: function (scope, element, attrs, controllers) {
                var myController = controllers[0];
                myController.GetsiteConT($stateParams.siteId);
            }

        }
    }]);

    /*******************************************************************************************************************************************************************************/

})(angular);






