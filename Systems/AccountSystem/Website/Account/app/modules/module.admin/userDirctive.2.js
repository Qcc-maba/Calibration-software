
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.admin')
        .directive('user', userFactory);
    /***********************************************************************************************************************************************************/
    function userFactory() {
        return {
            restrict: 'EA',
            templateUrl: 'app/modules/module.admin/user.html',
            controller: ['$scope', 'adminProxy', '$stateParams', '$filter', '$state', function ($scope, adminProxy, $stateParams, $filter, $state) {

                $scope.ladda = {
                    delUser: false,
                    lock: false,
                    reset: false,
                    UIFormat: false,
                    setRoles:false
                }
                $scope.deleteConfirm = "";
                var email = $stateParams.email;
        

               

                $scope.setUIFormat = function (l) {
                    $scope.ladda.UIFormat = true;
                    $scope.currentUIFormat.uiFormatID = l.uiFormatID;
                    $scope.currentUIFormat.displayName = l.displayName;
                    adminProxy.setUIFormat(email,l.uiFormatID)
                        .success(function (data) {
                            $scope.ladda.UIFormat = false;
                            toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                        }).error(function (data, status, headers, config) {
                            toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));

                        });
                }

                $scope.currentUIFormat = {
                    uiFormatID: "",
                    displayName:""
                }
              
                $scope.resetPassordObj= {
                    "newPassword": "",
                    "confirmPassword": "",
                    "email": email
                }
                $scope.passwordFormValidation = false;

                $scope.resetPass = function (passwordForm) {
                    $scope.ladda.reset = true;
                    if (passwordForm) {
                        $scope.passwordFormValidation = false;
                        adminProxy.resetPass($scope.resetPassordObj)
                        .success(function (data) {
                    
                            $scope.resetPassordObj = {
                                "newPassword": "",
                                "confirmPassword": "",
                                "email": email
                            }
                            $scope.ladda.reset = false;
                            toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                        }).error(function (data, status, headers, config) {
                            toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));

                        });

                    } else {
                        $scope.passwordFormValidation = true;
                    }
                }
                $scope.lockUnLock = function (bool) {
                    $scope.ladda.lock = true;
                    adminProxy.lockUnLock(email, bool)
                        .success(function (data) {
                            $scope.user.userProfile.lockoutEnabled = bool;
                            toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                            $scope.ladda.lock = false;
                        }).error(function (data, status, headers, config) {
                            toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
                  
                        });

                }
                $scope.delete = function () {
                    if ($scope.user.userProfile.email == $scope.deleteConfirm) {

                    
                        $scope.ladda.delUser = true;
                        adminProxy.delUser(email)
                             .success(function (data) {
                                 $scope.ladda.delUser = true;
                                 toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                                 $state.go('admin.users');
                                 $('#deleteUser').modal('hide');
                             }).error(function (data, status, headers, config) {
                                 toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));
                                 $('#deleteUser').modal('hide');
                             });
                    } else {

                    }

                }

                $scope.nevigateTo = function () {

                    var url = window.location.href;
                    var index = url.indexOf("/Account");
                    var prefix = url.substr(0, index)

                    window.location = prefix + '/?box=app';
                }
                var getUser = function (email) {

                    return adminProxy.getUser(email)
                        .success(function (data) {
                            $scope.user = data.body;
                            getUIFormats();
                            getUserRoles();
                      
                        })
                }
                var getUIFormats = function () {

                    return adminProxy.getUIFormats()
                        .success(function (data) {
                            $scope.LanguageList = data.body;
                            for (var i = 0; i < $scope.LanguageList.length; i++) {
                                $scope.LanguageList[i].imgURL = '../../../../Content/img/' + $scope.LanguageList[i].cultureCode + '.png';
                            }
                            for (var i = 0; i < data.body.length; i++) {
                               
                                if (data.body[i].uiFormatID == $scope.user.userProfile.uiFormatID) {
                                    $scope.currentUIFormat.uiFormatID = data.body[i].uiFormatID;
                                    $scope.currentUIFormat.displayName = data.body[i].displayName;
                                }
                            }
                        });
                }
                var getUserRoles = function () {

                    return adminProxy.getUserRoles(email)
                        .success(function (data) {
                            $scope.roles = data.body;
                        });
                }
                $scope.setUserRoles = function () {
                    $scope.ladda.setRoles = true;
                    return adminProxy.setUserRoles(email, $scope.roles)
                        .success(function (data) {
                     
                            toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                            $scope.ladda.setRoles = false;
                        }).error(function (data, status, headers, config) {
                            toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));

                        });
                }
               
                getUser(email);

            }],
            link: function (scope, element, attrs, ngModel) {
            }
        };
    }
})(angular);