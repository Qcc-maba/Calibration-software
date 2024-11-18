(function (angular) {
    'use strict';

    angular.module('module.widgets')
      .directive('messageList', messageListFactory);

    /**********************************************************************************************************************************************************************/
    function messageListFactory() {

        return {
            restrict: 'A',
            templateUrl: 'app/modules/module.message/messageList.html',
            controller: ['$scope', 'profileProxy','mainRouter', function ($scope, profileProxy,mainRouter) {
                //***************************************Attributs***************************************
                $scope.load = 1;
                //***************************************GetMessages***************************************
                $scope.GetMessages = function (load) {

                    profileProxy.GetMessages(load)
                              .success(function (data) {
                                  $scope.Messages = data.body.messages;
                              });
                }
                //********************************************************
                mainRouter.register("messageList", function (data) {
                    $scope.GetMessages($scope.load);
                });

                //******************************************************************************
                $scope.showMsg = function (id) {
                    profileProxy.GetMessage(id)
                              .success(function (data) {
                                  //$scope.Message = data.body;
                                  $scope.$broadcast('Message', data.body);
                              });
                    
                }
                //***************************************loadMore***************************************
                $scope.loadMore = function () {
                    $scope.load++;
                    $scope.GetMessages($scope.load);

                }
                $scope.GetMessages($scope.load);
            }],
            link: function (scope, element, attr) {

                element.bind('click', function (e) {
                    if ($(e.target).closest('.media').length) {
                        $(element).parent().css({ right: 270 });
                    } else {

                    }
                })
               
            }
        }

    }
})(angular);