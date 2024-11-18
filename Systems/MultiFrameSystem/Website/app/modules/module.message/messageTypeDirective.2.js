(function (angular) {
    'use strict';

    angular.module('module.widgets')
      .directive('messageType', messageTypeFactory);

    /**********************************************************************************************************************************************************************/
    function messageTypeFactory($log) {

        return {
            restrict: 'A',
            templateUrl: 'app/modules/module.message/messageType.html',
            controller: ['$scope', 'projectProxy', 'profileProxy', '$state', 'user','mainRouter', function ($scope, projectProxy, profileProxy, $state, user, mainRouter) {
                //********************************************Attributs*******************************
                $scope.newMsg = {
                    content: ""
                };
                $scope.newProjectName = {
                    name:""
                }
             
                //********************************************$on('Message')*******************************
                //mainRouter.register("oneMessage", function (data) {
                //    if (data.record.folderingTypeID == 3 || data.record.folderingTypeID == 4) {
                //        $scope.GetAllProjects();
                //        $scope.type = { state: "exists" };
                //    }
                //    $scope.fullMessage = data;
                //    $scope.message = data.record;
                //});
                //*****************************************************************************************
                $scope.$on('Message', function (event, data) {
                    if (data.record.folderingTypeID == 3 || data.record.folderingTypeID == 4) {
                        $scope.GetAllProjects();
                        $scope.type = { state: "exists" };
                    }
                    $scope.fullMessage = data;
                    $scope.message = data.record;
                });
                ///********************************************AcceptSite********************************************************************
                $scope.Accept = function (status,type) { // status 3 for reject 2 for accept
                        var obj = {
                            record:{
                                projectName: "",
                                projectId: ""
                            },
                            MessageID: $scope.fullMessage.messageID,
                            MessageType: $scope.fullMessage.messageType,
                            Status: status
                        }
            
                        if (type== 'exists') {
                            obj.record.projectName = $scope.choosenProjectName;
                            obj.record.projectId = $scope.choosenProjectId;
                        }
                        else {
                           
                            obj.record.projectName = $scope.newProjectName.name;
                        
                        }
                        profileProxy.acceptMessage(obj)
                                          .success(function (data) {
                                              if (data.body.projectID) { //accept
                                                  //nevigate to the new site
                                                  $state.go('site.preview.map', { siteId: data.body.projectID });
                                                  // add the new site to the tree (refresh tree)
                                                  mainRouter.callkey("tree", {});
                                                 

                                              } else { // reject

                                              }


                                              //general operation in case of accept/reject
                                              //**********************************************
                                              //close messages div
                                              if ($('#page-sidebar').css("right") == "0px") {
                                                  $('#page-sidebar').css("right", "-500px");
                                                  //element.removeClass('open');
                                              } else {
                                                  $('#page-sidebar').css("right", "0px");
                                                  //element.addClass('open');
                                              }
                                              // dec 1 message from messages list(refresh messageList)
                                              mainRouter.callkey("messageList", {});

                                              //dec 1 message from message counter
                                              user.Messages.messageNum = user.Messages.messageNum - 1;
                        });
                    //send to server
                    //clean the object
                   
                   

                }
                ///************************************************GetAllProjects****************************************************************
                $scope.GetAllProjects = function () {
                    projectProxy.GetAllProjects()
                                       .success(function (data) {
                                           if (data.body.length > 0) {
                                               $scope.type.state = 'exists';
                                               $scope.projectsList = data.body;
                                               $scope.choosenProjectName = $scope.projectsList[0].name;
                                               $scope.getChoosenProject($scope.projectsList[0].projectID, $scope.choosenProjectName);
                                           } else {
                                               $scope.type.state = 'new';
                                           }
                                           });

                }


                ///**************************************************getChoosenProject**************************************************************
                $scope.getChoosenProject = function (projectId, projectName) {
                    $scope.choosenProjectId = projectId;
                    $scope.choosenProjectName = projectName;

                }
                ///****************************************************************************************************************
            }],
            link: function (scope, element, attr) {

                element.bind('click', function (e) {

                    if ($(e.target).hasClass('sidebar-back')) {
                        $('#users').attr("style", { right: "0px" });
                    } else {

                    }
                })
            }
        }

    }
})(angular);