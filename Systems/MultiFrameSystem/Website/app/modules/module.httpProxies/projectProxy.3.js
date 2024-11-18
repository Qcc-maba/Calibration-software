
(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.httpProxies')
        .provider('projectProxy', projectProxy);


    //////////////// JavaScript //////////////

    function projectProxy() {

        var data = {
            serverURI: ""
        }


        return {

            $get: function ($http, baseProxy) {

            //  var data = baseProxy.Global.data.serverUri + '/Admin/Project';
                var server_MF_api = baseProxy.Global.data.server_mf;
                var data = baseProxy.Global.data.serverMF + '/Admin/Project';
                ///////////////////////START DONE///////////////////////////////////////////////////////
                function _GetProjects(currentPage, freeText, PageSize) {
                    //return $http.get(data + '/Tree/?PageNumber=' + currentPage + '&Search=' + freeText + '&PageSize=' + PageSize);
                    return $http.get(server_MF_api + '/Project/Tree/?PageNumber=' + currentPage + '&Search=' + freeText + '&PageSize=' + PageSize);
                };
                function _GetProjectsById(siteId, pageSize) {
                    //return $http.get(data + '/Tree/'+siteId+'?PageSize=' + pageSize);
                    return $http.get(server_MF_api + '/Project/Tree/' + siteId + '?PageSize=' + pageSize);
                };
                function _GetAllProjects() {
                    return $http.get(data + '/Projects');
                };
                function _saveNewProject(p, lat, lan) {
                    //return $http.post(data + '/?ProjectName=' + p, baseProxy.buildLocation(lat, lan));
                    return $http.post(server_MF_api + '/Project?ProjectName=' + p, baseProxy.buildLocation(lat, lan));
                };
              
                function _DeleteProject(id) {
                    //return $http.delete(data + '/' + id);
                    return $http.delete(server_MF_api + '/Project/' + id);
                };
                function _getProjectAlerts(projectId, includeSub , pageNumber , pageSize) {
                    //return $http.get(data + '/' + projectId + "/Alerts?IncludedSub=" + includeSub + "&PageNumber=" + pageNumber + "&PageSize=" + pageSize);
                    return $http.get(server_MF_api + '/Project/' + projectId + "/Alerts?IncludedSub=" + includeSub + "&PageNumber=" + pageNumber + "&PageSize=" + pageSize);
                };
                function _macroAlerts(projectId, includeSub , status) {
                    //return $http.post(data + '/' + projectId + "/MacroAlerts?IncludedSub=" + includeSub + "&Status=" + status);
                    return $http.post(server_MF_api + '/Project/' + projectId + "/MacroAlerts?IncludedSub=" + includeSub + "&Status=" + status);
                };
                function _postAlertsTableData(projectId,alerts) {
                    //return $http.post(data + '/' + projectId + "/Alerts", alerts);
                    return $http.post(server_MF_api + '/Project/' + projectId + "/Alerts", alerts);
                };
                function _exchange() {
                    //return $http.get(data + '/Exchange');
                    return $http.get(server_MF_api + '/Project/Exchange');
                };



             
           

                //interface
                return {

                    GetProjects: _GetProjects,
                    GetProjectsById:_GetProjectsById,
                    GetAllProjects:_GetAllProjects,
                    postAlertsTableData:_postAlertsTableData,
                    saveNewProject: _saveNewProject,
                    DeleteProject: _DeleteProject,
                    macroAlerts:_macroAlerts,
                    getProjectAlerts: _getProjectAlerts,
                    exchange: _exchange
                 
                  


                };
            }
        }
    }
})(angular);