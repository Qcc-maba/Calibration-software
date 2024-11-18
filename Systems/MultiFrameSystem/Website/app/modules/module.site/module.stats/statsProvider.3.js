
(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.site.stats')
        .provider('stateService', stateService);
    function stateService() {

        var date = {
            'startUnix': '',
            'endUnix': ''
        }
        //***********************getLastYear(Outer)****************
        function getLastYear() {
            var GmtAbs = localTime.getTimezoneOffset() * 60 * 1000;
            var localTime = new Date();
            var lastYear = localTime.setFullYear(localTime.getFullYear() - 1)
            date.end = localTime.getTime() - GmtAbs;
            date.start = lastYear.getTime() - GmtAbs;
            return date;
        }
        //***********************getLastMonth(Outer)****************
        function getLastMonth () {
            var GmtAbs = localTime.getTimezoneOffset() * 60 * 1000;
            var localTime = new Date();
            var lastMonth = localTime.setMonth(localTime.getMonth() - 1)
            date.end = localTime.getTime() - GmtAbs;
            date.start = lastYear.getTime() - GmtAbs;
            return date;
        //***********************getLastWeek(Outer)****************   
        }
        function getLastWeek() {
            var GmtAbs = localTime.getTimezoneOffset() * 60 * 1000;
            var localTime = new Date();
            var lastWeek = new Date(today.getFullYear(), today.getMonth(), today.getDate() - 7);
            date.end = localTime.getTime() - GmtAbs;
            date.start = lastWeek.getTime() - GmtAbs;
            return date;
        }
        //***********************strDateToUnix(Outer)****************   
        function strDateToUnix(dateStr) {
            var x = new Date(dateStr.start);
            date.start = x.getTime();
            var x = new Date(dateStr.end);
            date.end = x.getTime();
            return date;
        }
        return {
            $get: function () {
                //interface
                return {
                   
                    getLastYear: getLastYear,
                    getLastMonth: getLastMonth,
                    getLastWeek: getLastWeek
                 
                };
            }
        }
    }
})(angular);





