(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.profile')
        .directive('profile', profileFactory);



    function profileFactory() {
        return {
            restrict: 'EA',

            templateUrl: 'app/modules/module.profile/profile.html',

            controller: function ($scope, adminProxy, $translate, tmhDynamicLocale) {
                $scope.imgUrl = ROOT_ADDR.SYSTEM_ACCOUNT_API + "/Account/Profile/Image";
                $scope.validation = {
                    "profile": false,
                    "password": false,
                    "changePassword": false
                }
                $scope.changePasswordObject = {
                    "oldPassword": "",
                    "newPassword":"",
                    "confirmPassword":""
                }
                $scope.ladda = {
                 saveProfile:false,
                };
                var precent;
                var fill;
                //***********************************shortToFull**************************************************

                function shortToFull(short) {
                    switch (short) {
                        case "en":
                            return "English"
                            break;
                        case "es":
                            return  "Español"
                            break;
                        case "fr":
                            return "français"
                            break;

                    }
                    return "English"
                }
                //************************************************************GetCoockie*************************************************************
                function getCookie(cname) {
                    var name = cname + "=";
                    var ca = document.cookie.split(';');
                    for (var i = 0; i < ca.length; i++) {
                        var c = ca[i];
                        while (c.charAt(0) == ' ') c = c.substring(1);
                        if (c.indexOf(name) == 0) return c.substring(name.length, c.length);
                    }
                    return "";
                }
                //************************************************************setCookie*********************************
                function setCookie(cname, cvalue, exdays) {
                    var d = new Date();
                    d.setTime(d.getTime() + (exdays * 24 * 60 * 60 * 1000));
                    var expires = "expires=" + d.toUTCString();
                    document.cookie = cname + "=" + cvalue + "; path=/;" + expires;
                   // document.cookie = cookieName + "=" + cookieValue + ";domain=.example.com;path=/;expires=" + myDate;
                }
                //**************************************************************************************
                function getUsersKit() {

                    return adminProxy.getUsersKit()
                        .success(function (data) {
                            $scope.culture = data.body.uiFormats;
                            for (var i = 0; i < $scope.culture.length; i++) {
                                $scope.culture[i].imgURL = '../../../../Content/img/'+$scope.culture[i].cultureCode + '.png';
                            }
                            $scope.timeZone = data.body.timeZones;
                            $scope.temperatureUnit = data.body.temperatureUnits;
                            reloadUser();
                        });
                };
                //********************************************************************************
                $scope.chooseCulture = function(cl) {
                    $scope.ExtraDetails.culture = cl.displayName;
                    $scope.ExtraDetails.cultureCode = cl.cultureCode;
                    if (cl.cultureCode == 'He-Iljjjj') {
                    
                        $translate.use(cl.cultureCode);
                        tmhDynamicLocale.set(cl.cultureCode);
                    }else{
                     
                        $translate.use('en');
                        tmhDynamicLocale.set('en');
                      
                    }
                }
                //*********************************************************************************
                $scope.chooseTimeZone= function(tz) {
                    $scope.ExtraDetails.timeZone = "UTC - " + tz.gmtOffset / 60 + " " + tz.displayName;
                    $scope.ExtraDetails.zoneID = tz.zoneID;
                }
                //*********************************************************************************
                $scope.chooseTemperatureUnit = function (tu) {
                    $scope.ExtraDetails.temperatureUnit = tu.displayName;
                    $scope.ExtraDetails.typeUnitID = tu.typeUnitID;
                }
                //********************************************************************************
                function checkUserExtraDetails(userDetails) {
                    for (var i = 0; i < $scope.culture.length; i++) {
                        if ($scope.culture[i].cultureCode == userDetails.cultureCode) {
                            $scope.ExtraDetails.culture = $scope.culture[i].displayName;
                            $scope.ExtraDetails.cultureCode = $scope.culture[i].cultureCode;
                            break;
                        }
                    }
                    for (var i = 0; i < $scope.timeZone.length; i++) {
                        if ($scope.timeZone[i].zoneID == userDetails.timeZoneID) {
                            $scope.ExtraDetails.timeZone = "UTC " + $scope.timeZone[i].gmtOffset / 60 + " " + $scope.timeZone[i].displayName;
                            $scope.ExtraDetails.zoneID = $scope.timeZone[i].zoneID;
                            break;
                        }
                    }
                    for (var i = 0; i < $scope.temperatureUnit.length; i++) {
                        if ($scope.temperatureUnit[i].typeUnitID == userDetails.temperatureUnitID) {
                            $scope.ExtraDetails.temperatureUnit = $scope.temperatureUnit[i].displayName;
                            $scope.ExtraDetails.typeUnitID = $scope.temperatureUnit[i].typeUnitID;
                            break;
                        }
                    }
                }
                //*********************************************************************************************
                function reloadUser() {
                    return adminProxy.loadCurrentProfile()

                        .success(function (data) {
                            $scope.ExtraDetails = {};
                            $scope.userData = data.body;
                            checkUserExtraDetails($scope.userData);
                           

                        });
                };
                //********************************************setUserLanguage******************************
                $scope.setUserLanguage = function (short) {
                    $scope.selectedLenguage = shortToFull(short);
                    $scope.userData.cultureCode = short;
               
                }
                //****************************************************************
                $scope.saveUser = function (profileForm) {
                    if (profileForm) {
                        $scope.ladda.saveProfile = true;
                        $scope.validation.profile = false;
                        $scope.userData.timeZoneID = $scope.ExtraDetails.zoneID;
                        $scope.userData.temperatureUnitID = $scope.ExtraDetails.typeUnitID;
                        $scope.userData.cultureCode = $scope.ExtraDetails.cultureCode;
                        return adminProxy.SaveCurrentProfile($scope.userData)
                          .success(function (data, status, headers, config) {
                              //$translate.use($scope.data.cultureCode);
                              //tmhDynamicLocale.set($scope.data.cultureCode);
                              //setCookie("selectedLanguage", $scope.data.cultureCode, 30);
                              $scope.ladda.saveProfile = false;
                              toastr.success(' Details  Saved', 'Success!');
                         
                          }).error(function (data, status, headers, config) {
                              toastr.error('Details Not Saved', 'Error!');
                          });
                    } else {
                        $scope.validation.profile = true;
                    }
                }
                //***********************************************************
                $scope.changePassword = function (changePasswordForm) {
                    if (changePasswordForm) {
                        $scope.ladda.changePassword = true;
                        $scope.validation.changePassword = false;
                        return adminProxy.resetPassword($scope.changePasswordObject)
                          .success(function (data, status, headers, config) {
                              $scope.ladda.changePassword = false;
                              toastr.success(' Details  Saved', 'Success!');

                          }).error(function (data, status, headers, config) {
                              toastr.error('Details Not Saved', 'Error!');
                          });
                    } else {
                        $scope.validation.changePassword = true;
                    }
                }
                //**************************************************************
                $scope.myCallback = function (valueFromDirective) {
          
                    if (valueFromDirective.result) {

                        $scope.userData.imgURL = valueFromDirective.body;
                       
                        toastr.success('New Image  Saved', 'Success!');
                        resetLoading();
                        $scope.$apply();
                    } else {
                        toastr.error('Faild Upload Image', 'Error!');


                        resetLoading();
                        $scope.$apply();
                    }

                };

                //**********************************************************
                function resetLoading() {
                
                        $('.profileFixLoadingImage').css({ 'display': 'none' });
                        fill.width('0');
                        precent.html(0+ "%");
                       
                   
                }
                //*******************************************************************
                $scope.myANCallback = function (val) {

                    $('.profileFixLoadingImage').css({ 'display': 'block' });
                     precent = $('.loadingContainer .precent');
                     fill = $('.loadingContainer .loadingBar .fill');
                };
                //***************************************************************
                

                $scope.progress = function (val) {  // full width = 216px
                    precent.html(parseInt(val) + "%");
                    var currentWidth = parseInt ((val / 100) * 216);
                    fill.width(currentWidth);
                    $scope.$apply();
                    
                };
                //**************************************************
                getUsersKit();
              
               

            },
            link: function (scope, element, attrs, ngModel) {
                $("#navbar").css("display", "none");


            }




        };

    }
})(angular);




