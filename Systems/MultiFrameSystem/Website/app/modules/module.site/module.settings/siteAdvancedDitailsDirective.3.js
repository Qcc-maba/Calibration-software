
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.site.settings')
        .directive('siteAdD', siteAdDFactory);
    /*********************************************************************Weather****************************************************************************************************/
    function siteAdDFactory($log) {



        return {
            restrict: 'EA',
            require: '?ngModel',
            templateUrl: 'app/modules/module.site/module.settings/settings.html',

            controller: function ($scope, $stateParams, projectProxy, baseProxy, siteProxy, $filter, user, directiveComm,translate) {

               
                $scope.daySettingConnector = directiveComm.CreateConnector();
                $scope.transferType = "Outer";
                $scope.isValid = false;
                $scope.ladda = {
                    season: false,
                    deleteSite: false,
                    share: false,
                    transfer: false
                };
   
               
                $scope.addUser = {
                    email: "",
                    roleViewOnly: false,
                    roleModify: false,
                    roleControlRT: false,
                    roleAdmin: true
                }
                $scope.userEmailTransfer = { address: "" };
                $scope.emailExistTransfer = true;
                $scope.userEmailShare;
                $scope.emailExistShare = true;
                //**********************************************************************************
                $scope.getSessons = function (siteID) {
                    siteProxy.getSessonList(siteID)
                                      .success(function (data) {
                                          $scope.newSeasson = {
                                              name: "",
                                              startDate: "",
                                              endDate: "",
                                              isAutoUpdate: false,
                                              sessionID: -1,
                                              isDelete: false
                                          }
                                          $scope.SiteSeassonList = data.body;
                                          pharseFirstSeassonDates($scope.SiteSeassonList);

                                      });
                }
                //**********************************************************************************
                function pharseFirstSeassonDates(SiteSeassonList) {
                    for (var i = 0; i < SiteSeassonList.length; i++) {
                        if (SiteSeassonList[i].startDate) {
                            SiteSeassonList[i].startDateStr = $filter('date')(SiteSeassonList[i].startDate, 'longDate');
                        }
                        if (SiteSeassonList[i].endDate) {
                            SiteSeassonList[i].endDateStr = $filter('date')(SiteSeassonList[i].endDate, 'longDate');
                        }
                    }
                }
                $scope.saveLastDateObject = function (obj) {
                    $scope.lastObj = jQuery.extend(true, {}, obj);
                }
                //***************************************************************************************************************
                $scope.dateValidateAndPharse = function (index, type, element, val) {
                    val = parseInt(val);
                    var cont = index == "-1" ? $scope.newSeasson : $scope.SiteSeassonList[index];
                    if (type == 'start') {
                        if (startDateValidate(val, index, $scope.SiteSeassonList)) {
                            
                            pharseDate(cont, val, type);
                        } else {
                            toastr.error('Start Date Error', 'Error!');
                            if (index != "-1") {
                                element.val($scope.lastObj.startDateStr);
                                cont.startDate = $scope.lastObj.startDate;
                                cont.startDateStr = $scope.lastObj.startDateStr;
                            }else{
                                //$.datepicker._clearDate(element);
                                if ($scope.newSeasson.startDate != "") {
                                    element.val($scope.newSeasson.startDateStr);
                                    cont.startDate = $scope.newSeasson.startDate;
                                    cont.startDateStr = $scope.newSeasson.startDateStr;
                                } else {
                                    element.val('');
                                }
                              
                           }
                         
                          
                         
                        }
                    }
                    if (type == 'end') {
                        if (endDateValidate(val,index, $scope.SiteSeassonList)) {
                    
                            pharseDate(cont,val, type);
                        } else {
                 
                            toastr.error('End Date Error', 'Error!');
                            if (index != "-1") {
                                element.val($scope.lastObj.endDateStr);
                                cont.endDate = $scope.lastObj.endDate;
                                cont.endDateStr = $scope.lastObj.endDateStr;
                            } else {
                                //$.datepicker._clearDate(element);
                                element.val('');


                                if ($scope.newSeasson.endDate != "") {
                                    element.val($scope.newSeasson.endDateStr);
                                    cont.endDate = $scope.newSeasson.endDate;
                                    cont.endDateStr = $scope.newSeasson.endDateStr;
                                } else {
                                    element.val('');
                                }
                            }
                        }
                    }
                    
                }
                //*************************************************************************
                function startDateValidate(val, index, seassonList) {
                    if(val){
                    if (index >= 0) {
                        if (seassonList[index].endDate) {
                            if (val >= seassonList[index].endDate) {
                                return false;
                            }
                        }
                        if (index > 0 && val < seassonList[index - 1].endDate) {
                            return false;
                        }
                    }
                    if (index == "-1") {
                  
                        if ($scope.newSeasson.endDate) {
                            if (val >= $scope.newSeasson.endDate) {
                                return false;
                            }
                        }
                        if (val < seassonList[seassonList.length-1].endDate) {
                            return false;
                        }
                    }
               

                    return true;
                    }
                    return false;
                }
                //*********************************************************************
                function endDateValidate(val, index, seassonList) {
                    if (index == '-1' && (($scope.newSeasson.startDate != "" && val < $scope.newSeasson.startDate) || (val < seassonList[seassonList.length - 1].endDate))) {
                        return false;
                    }
                    if (index != '-1'){
                    if (val < seassonList[index].startDate) {
                        return false;
                    }
                    if (index < seassonList.length-1 && val >= seassonList[index+1].startDate) {
                        return false;
                    }
                    if (index == seassonList.length - 1 && ($scope.newSeasson.startDate != "" && val >= $scope.newSeasson.startDate) ){
                        return false;
                    }
                    }
                    return true;
                }

                //*************************************************************************************
                function pharseDate(obj,val , type) {
                    if(type=='start'){
                        obj.startDate = val;
                        obj.startDateStr = $filter('date')(val, 'longDate');
                        //$rootScope.$digest()
                    }
                    if (type == 'end') {
                        obj.endDate = val;
                        obj.endDateStr = $filter('date')(val, 'longDate');
                        //$rootScope.$digest()
                    }
                  
                }
                //**********************************************************************************
                $scope.getOneSesson = function (sessonID) {
                    siteProxy.getOneSesson($scope.siteId, sessonID)
                                      .success(function (data) {
                                          $scope.SeassonModalTable = data;
                                          $scope.daySettingConnector.CallbackDown($scope.SeassonModalTable);
                                      });
                }
                //***********************************************************
                $scope.daySettingConnector.SetCallbackUp(function (data) {
                
                    $('#specificSeasson').modal('hide');

                });
                //************************************************************
                $scope.saveSessons = function () {
                   

                    
                    $scope.ladda.season = true;
                    if ( ($scope.newSeasson.startDate != '') && ($scope.newSeasson.endDate != '')) {
                        $scope.SiteSeassonList.push($scope.newSeasson);
                    }
                    siteProxy.saveSessonList($scope.siteId, $scope.SiteSeassonList)
                    
                                      .success(function (data) {
                                          $scope.getSessons($scope.siteId);
                                          
                                          $scope.ladda.season = false;
                                          toastr.success('Details Saved', 'Success!');
                                     
                                      });
                    
                }
                //******************************************************************************
                $scope.sharingData = user.getSharingData().sharingData;
                ///**************************************************GetAllProjects**************************************************************
                $scope.GetAllProjects = function () {
                projectProxy.GetProjects(1, "", 10)
                                .success(function (data) {

                                    $scope.projectsList = data.projects;
                                    $scope.choosenProjectName = $scope.projectsList[0].name;
                                    $scope.getChoosenProject($scope.projectsList[0].projectID, $scope.choosenProjectName);
                                    fixLoadingOff();

                                });

                }
                ///*************************************filterSearch***************************************************************************
                $scope.filterSearch = function (txt) {
                    

                }
                ///**************************************************getChoosenProject**************************************************************
                $scope.getChoosenProject = function (projectId, projectName) {
                    $scope.choosenProjectId = projectId;
                    $scope.choosenProjectName = projectName;
                }
                ///****************************addSeassonRow************************************************************************************
                $scope.addNewSeasson = function () {
                    
                }
                ///****************************saveAndAdd************************************************************************************
                $scope.saveAndAdd = function (bool) {
                    var x = angular.copy($scope.extraSeasson);
                    if (bool == true) {
                        $scope.isValid = true;
                        //not valid, not add it but send data to services
                     
                    }
                    if (bool == false) {
                        // valid ,add it send data to services
                        $scope.isValid = false;

                        $scope.SiteSeassonList.SSL.push(x);
                      
                        $scope.extraSeasson.SeassonName = "";
                        $scope.extraSeasson.StartDate = "";
                        $scope.extraSeasson.EndDate = "";
                        $scope.extraSeasson.AutoUpdate = "";
                        $scope.extraSeasson.Weekly = "";
                    }
                  

                }
                ///***************************saveSeassonWeekly*************************************************************************************
                $scope.saveSeassonWeekly = function (func) {
                    func();
                }
                //*****************************************************************************
                $scope.GetAllProjects();
                //****************************************************************************
               
                //************************************************functions*******************
                //*************************************************getSharingList****************
                $scope.getSharingList = function (projectId) {
                    siteProxy.getSharingList(projectId)
                                       .success(function (data) {
                                           $scope.usersList = data.body;
                                       });

                }
                //*****************************************************transferProject(Outer)****************
                $scope.getTransferStatus = function (projectId) {
                    siteProxy.getTransferStatus(projectId)
                                       .success(function (data) {
                                           $scope.transferStatus = data.body;

                                       });
                }
                //*****************************************************transferProject(Outer)****************
                $scope.transferProject = function (projectId) {

                    $scope.ladda.transfer = true;
                    siteProxy.transferProject(projectId, $scope.userEmailTransfer.address)
                                  .success(function (data) {
                                      if (!data.body) {
                                          var msgNum = data.messages[0].code;
                                          toastr.error($filter('translate')(msgNum));

                                      }
                                      $scope.ladda.transfer = false;
                                      $scope.transferObj = data.body;
                                      $scope.ladda.transfer = false;
                                      $scope.transferStatus = data.body;
                                  }).error(function (data, status, headers, config) {

                                  });

                }
                //*************************************************cancelTransfer(Outer)****************
                $scope.cancelTransfer = function () {
                    siteProxy.cancelTransfer($scope.siteId)
                                       .success(function (data) {
                                         
                                           $scope.transferStatus.transferStatus = 0;
                                       });

                }
                //*************************************************cancelTransfer(Outer)****************
                $scope.deleteUser = function (userId) {
                    siteProxy.deleteUser($scope.siteId, userId)
                                         .success(function (data) {
                                             if (data.body) {
                                                 for (var i = 0 ; i < $scope.usersList.length; i++) {
                                                     if ($scope.usersList[i].linkedUserID == userId) {
                                                         $scope.usersList.splice(i, 1);
                                                     }
                                                 }
                                             } else {
                                                 toastr.error($filter('translate')('toastrErrMsgSave'));
                                             }
                                         }).error(function (data) {
                                             toastr.error($filter('translate')('toastrErrMsgSave'));
                                         });

                }
                //*************************************************shareProject(Outer)****************
                $scope.shareProject = function () {


                    if ($scope.shareForm.$valid) {
                        $scope.ladda.share = true;
                        //send to server
                        $scope.ladda.share = false;
                        $scope.emailValidationShare = false;
                    } else {
                        $scope.emailValidationShare = true;
                    }
                }
                //**************************************************************************************
                $scope.localTransfer = function () {
                    siteProxy.localTransfer($scope.choosenProjectId, $scope.siteId)
                                      .success(function (data) {
                                         
                                      })
                                     .error(function (data) {
                                         toastr.error($filter('translate')(data));
                                     });
                }
                //*************************************************cancelTransfer(Outer)****************
                $scope.sendShareUser = function () {
                    if ($scope.addUser.email.length > 0) {
                        var temp = $scope.usersList.slice(0);
                        temp.push($scope.addUser);
                        siteProxy.sendShareUser($scope.siteId, temp)
                            .success(function (data) {
                                $scope.addUser.email = "";
                                if (!data.body) {
                                    var msgNum = data.messages[0].code;
                                    toastr.error($filter('translate')(msgNum));

                                } else {
                                    $scope.usersList = data.body;
                                }
                            })
                           .error(function (data) {
                            });
                    } else {
                        siteProxy.sendShareUser($scope.siteId, $scope.usersList)
                           .success(function (data) {
                               if ($scope.addUser.email.length > 1) {
                                   $scope.addUser.email = "";
                               }
                           })
                            .error(function (data) {
                                $scope.addUser.email = "";
                            });
                    }
                }
            },
            link: function (scope, element, attrs, ngModel) {
                if (!ngModel) return; // do nothing if no ng-model
                ngModel.$render = function () {

                    scope.siteId = ngModel.$viewValue;
                    fixLoadingOff();
                    scope.getSharingList(scope.siteId);
                    scope.getTransferStatus(scope.siteId);
                    scope.getSessons(scope.siteId)
                  


                };

            }




        };
    }

    /*******************************************************************************************************************************************************************************/

})(angular);






