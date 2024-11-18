
(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.httpProxies')
        .provider('statsProxy', statsProxy);


    //////////////// JavaScript //////////////

    function statsProxy() {



        return {

            $get: function ($http, baseProxy) {

                var data = baseProxy.Global.data.serverUri + '/Admin';
                ///////////////////////START DONE///////////////////////////////////////////////////////
           
                function _GetTopUsageLogSite(id, PageSize) {

                    return $http.get(data + "/Site/"+id+"/stats/Usage/?PageSize=" + PageSize);
                };
                function _getUsageLogSite(id, type,PageSize, date, currentPage) {

                    return $http.get(data + "/Site/" + id + "/stats/Usage/?PageSize=" + PageSize + "&PageNumber=" + currentPage + "&startDate=" + date.start + "&endDate=" + date.end);
                }
                function _GetTopAlertsLogSite(id, PageSize) {

                    return $http.get(data + "/Site/" + id + "/stats/Alerts/?PageSize=" + PageSize);
                };
                function _getAlertsLogSite(id, type, PageSize, date, currentPage) {

                    return $http.get(data + "/Site/" + id + "/stats/Alerts/?PageSize=" + PageSize + "&PageNumber=" + currentPage + "&startDate=" + date.start + "&endDate=" + date.end);
                }
                function _GetTopGeneralLogSite(id, PageSize) {

                    return $http.get(data + "/Site/" + id + "/stats/General/?PageSize=" + PageSize);
                };
                function _getGeneralLogSite(id, type, PageSize, date, currentPage) {

                    return $http.get(data + "/Site/" + id + "/stats/General/?PageSize=" + PageSize + "&PageNumber=" + currentPage + "&startDate=" + date.start + "&endDate=" + date.end);
                }
                function _getLinkData(id,sn, connectionId) {

                    return $http.get(data + "/Site/" + id +"/"+sn+ "/stats/General/" + connectionId);
                }
             
                function _GetStackDetails(id, from, to) {

                    return $http.get(data + "/Site/" + id + "/stats/Charts/?from=" + from + "&to=" + to);
                };









                //interface
                return {
                    GetTopUsageLogSite: _GetTopUsageLogSite,
                    getUsageLogSite: _getUsageLogSite,
                    GetTopAlertsLogSite: _GetTopAlertsLogSite,
                    getAlertsLogSite: _getAlertsLogSite,
                    GetTopGeneralLogSite: _GetTopGeneralLogSite,
                    getGeneralLogSite: _getGeneralLogSite,
                    getLinkData: _getLinkData,
                    GetStackDetails: _GetStackDetails
                





                };
            }
        }
    }
})(angular);