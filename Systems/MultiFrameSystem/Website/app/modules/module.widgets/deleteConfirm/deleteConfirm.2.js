(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('myDeleteConfirm', myDeleteConfirmFactory);



    function myDeleteConfirmFactory($log) {
        return {
            restrict: 'EA',
            require: '?ngModel',
            scope: {
                callback: "&"
            },
            templateUrl: 'app/modules/module.widgets/deleteConfirm/deleteConfirm.html',

            controller: ['$scope', 'siteProxy', function ($scope, siteProxy) {
                
                $scope.showValidation = false;
                $scope.myString = { str: '' };
                $scope.closeModal = function () {
                    $scope.myString.str = "";
                    $scope.Captcha();
                }
                $scope.Captcha = function() {
                    var alpha = new Array('A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z');
                    var i;
                    for (i = 0; i < 6; i++) {
                        var a = alpha[Math.floor(Math.random() * alpha.length)];
                        var b = alpha[Math.floor(Math.random() * alpha.length)];
                        var c = alpha[Math.floor(Math.random() * alpha.length)];
                        var d = alpha[Math.floor(Math.random() * alpha.length)];
                        var e = alpha[Math.floor(Math.random() * alpha.length)];
                        var f = alpha[Math.floor(Math.random() * alpha.length)];
                        var g = alpha[Math.floor(Math.random() * alpha.length)];
                    }
                    $scope.code = a + ' ' + b + ' ' + ' ' + c + ' ' + d + ' ' + e + ' ' + f + ' ' + g;
                    $scope.codeNotSpaces = removeSpaces($scope.code);
                }
                //***********************************************************************
                 $scope.getSiteName = function(siteId) {
                    siteProxy.getSiteName(siteId)
                      .success(function (data, status, headers, config) {
                          $scope.siteName = data.body.siteName;
                          $scope.projectOrSite = data.body.projectName;

                          if (data.body.projectID == data.body.siteID) { //delete project
                              $scope.projectOrSiteName = data.body.projectName;
                              $scope.type = "Project";
                          } else {
                              $scope.projectOrSiteName = data.body.siteName; // delete site
                              $scope.type = "Site";
                          }
                     
                        
                      })
                      .error(function (data, status, headers, config) {

                      });
                 }
                //**************************************************************************
                 $scope.getDeviceName = function (id) {
                     siteProxy.GetDeviceInfo(id)
                        .success(function (data) {
                            var devices = data.body.otherDevicesView;
                            for (var i = 0; i < devices.length; i++) {
                                if (devices[i].sn == id) {
                                    $scope.currentDevice = devices[i];
                                   
                                }
                            }
                        }).error(function (data, status, headers, config) {
                            toastr.error($filter('translate')('toastrErrMsgGet'));
                        });
                 }
                //***************************************************************************
                function ValidCaptcha() {
                    var string1 = removeSpaces($scope.code);
                    var string2 = removeSpaces($scope.myString.str);
                    if (string1 == string2) {
                        return true;
                    }
                    else {
                        return false;
                    }
                }
                function removeSpaces(string) {
                    return string.split(' ').join('');
                }

                $scope.confirm = function () {
                    $scope.showValidation = true;
                    if (ValidCaptcha()) {
                       
                        $scope.callback();
                        $scope.Captcha();
                    } else {
                        
                        $scope.Captcha();
                        toastr.error('Try Again', 'Error!');
                        
                    }
                    $scope.myString.str = "";
                }


                //************************
                $scope.Captcha();
            }],
            link: function (scope, element, attrs, ngModel) {

                if (!ngModel) return; // do nothing if no ng-model
                ngModel.$render = function () {
                    
                    scope.id = ngModel.$viewValue;  // siteId or sn
                    scope.text = attrs.str;
                    scope.text1 = attrs.str1;
                    scope.type = attrs.typeattr;
                    if (scope.id){
                        if (scope.type == 'site') {
                            scope.getSiteName(scope.id);
                        } else {
                            scope.getDeviceName(scope.id);
                        }
                    }

                };
               

            }




        };

    }
})(angular);