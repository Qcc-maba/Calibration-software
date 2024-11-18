
(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.widgets')
        .directive('paging', paging);


    //////////////// JavaScript //////////////



    function paging() {

        return {

            restrict: 'EA',
            templateUrl: 'app/modules/module.widgets/paging/paging.html',
            scope: {
                comm: '='
            },
            controller: function ($scope) {

                $scope.menu = {
                 
                    'prev': false,
                    'forward': false
                
                }

                var totalPages = 0;
                var currentPage = 0;


                $scope.comm.SetCallbackDown(function (newPageNumber, pageSize, TotalItems) {

                    totalPages = Math.ceil(TotalItems / pageSize);
                    currentPage = newPageNumber;

                    firstLast();
                    $scope.list = build_list_of_pages();
                  
                });

                function changePage(page) {
                    firstLast();
                    if (0 < page && page <= totalPages) {

                        $scope.comm.CallbackUp(page);

                        return true;
                    }

                    return false;
                }

                function firstLast() {

                    if (currentPage == 1) {
                        $scope.menu.prev = true;
                       

                    }
                    else {
                        $scope.menu.prev = false;
                    }

                    if (currentPage >= totalPages) {
                        $scope.menu.forword = true;
                 

                    }
                    else {
                        $scope.menu.forword = false;
                    }
                }

                function build_list_of_pages() {
                    var listOfObjects = [];

                    if (totalPages < 5) {
                        for (var i = 1 ; i <= totalPages; i++) {

                            var singleObj = {}
                            singleObj['value'] = i;
                            if (i == currentPage) {
                                singleObj['type'] = 'active';
                            } else {
                                singleObj['type'] = '';
                            }

                            listOfObjects.push(singleObj);
                        }
                    }
                    else {
                        if (currentPage - 1 >= 0) {
                            if (currentPage - 1 >= 2) {   //two page before current page
                                var singleObj1 = {}
                                singleObj1['value'] = currentPage - 2;
                                singleObj1['type'] = '';
                                listOfObjects.push(singleObj1);

                                var singleObj2 = {}
                                singleObj2['value'] = currentPage - 1;
                                singleObj2['type'] = '';
                                listOfObjects.push(singleObj2);

                                var singleObj3 = {}
                                singleObj3['value'] = currentPage;
                                singleObj3['type'] = 'active';
                                listOfObjects.push(singleObj3);

                                if (currentPage + 1 <= totalPages) {
                                    var singleObj4 = {}
                                    singleObj4['value'] = currentPage + 1;
                                    singleObj4['type'] = '';
                                    listOfObjects.push(singleObj4);
                                }
                                if (currentPage + 2 <= totalPages) {
                                    var singleObj5 = {}
                                    singleObj5['value'] = currentPage + 2;
                                    singleObj5['type'] = '';
                                    listOfObjects.push(singleObj5);
                                }
                            }
                            if (currentPage - 1 == 1) {//one page before current page

                                var singleObj1 = {}
                                singleObj1['value'] = currentPage - 1;
                                singleObj1['type'] = '';
                                listOfObjects.push(singleObj1);

                                var singleObj2 = {}
                                singleObj2['value'] = currentPage;
                                singleObj2['type'] = 'active';
                                listOfObjects.push(singleObj2);

                                var singleObj3 = {}
                                singleObj3['value'] = currentPage + 1;
                                singleObj3['type'] = '';
                                listOfObjects.push(singleObj3);

                                var singleObj4 = {}
                                singleObj4['value'] = currentPage + 2;
                                singleObj4['type'] = '';
                                listOfObjects.push(singleObj4);

                                var singleObj5 = {}
                                singleObj5['value'] = currentPage + 3;
                                singleObj5['type'] = '';
                                listOfObjects.push(singleObj5);
                            }
                            if (currentPage - 1 == 0) {//no page before current page

                                var singleObj1 = {}
                                singleObj1['value'] = currentPage;
                                singleObj1['type'] = 'active';
                                listOfObjects.push(singleObj1);

                                var singleObj2 = {}
                                singleObj2['value'] = currentPage + 1;
                                singleObj2['type'] = '';
                                listOfObjects.push(singleObj2);

                                var singleObj3 = {}
                                singleObj3['value'] = currentPage + 2;
                                singleObj3['type'] = '';
                                listOfObjects.push(singleObj3);

                                var singleObj4 = {}
                                singleObj4['value'] = currentPage + 3;
                                singleObj4['type'] = '';
                                listOfObjects.push(singleObj4);

                                var singleObj5 = {}
                                singleObj5['value'] = currentPage + 4;
                                singleObj5['type'] = '';
                                listOfObjects.push(singleObj5);
                            }
                        }
                    }
                    return listOfObjects;
                }

                function prevPage() {

                    changePage(currentPage - 1);
                }

                function firstPage() {
                    changePage(1);
                }

                function lastPage() {

                    changePage(totalPages);
                }

                function forwardPage() {

                    changePage(currentPage + 1);

                }


                $scope.build_list_of_pages = build_list_of_pages;
                $scope.prevPage = prevPage;
                $scope.firstPage = firstPage;
                $scope.lastPage = lastPage;
                $scope.forwardPage = forwardPage;
                $scope.changePage = changePage;

            }
        };
    
        
    }
})(angular);





