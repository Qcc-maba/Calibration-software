
(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.admin')
        .directive('users', usersFactory);
    /***********************************************************************************************************************************************************/
    function usersFactory() {
        return {
            restrict: 'EA',
            scope: {

            },
            templateUrl: 'app/modules/module.admin/users.html',
            controller: ['$scope', 'adminProxy', 'directiveComm', function ($scope, adminProxy, directiveComm) {
                var pageSize = 20;
                var currentPage = 1;
                $scope.search = "";
             
                $scope.paginationConector = directiveComm.CreateConnector();


                $scope.paginationConector.SetCallbackUp(function (pageNumber) {
                    getallUsers($scope.search, pageNumber, pageSize);
                });
                
               

                var getallUsers = function (search, pageNumber, pageSize) {
                    
                    return adminProxy.getallUsers(search, pageNumber, pageSize)
                        .success(function (data) {
                            currentPage = pageNumber;
                            $scope.pagerFlag = data.totalItems / pageSize > 1 ? true : false;
                            $scope.users = data.body;
                            $scope.paginationConector.CallbackDown(currentPage, pageSize, data.totalItems);
                            fixLoadingOff();
                        });
                }


                getallUsers($scope.search, currentPage, pageSize);



                $scope.nevigateTo = function () {

                    var url = window.location.href;
                    var index = url.indexOf("/Account");
                    var prefix = url.substr(0, index)

                    window.location = prefix + '/?box=app';
                }
                $scope.$watch('search', function (nVal, oVal) {
                    if (nVal !== oVal) {
                        fixLoadingOn();
                        currentPage = 1;
                        getallUsers(nVal, currentPage, pageSize);
                    }
                });
               
               
            }],
            link: function (scope, element, attrs, ngModel) {
                
            }

        };
    }

})(angular);






