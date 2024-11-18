
(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.httpProxies')
        .provider('profileProxy', profileProxy);


    //////////////// JavaScript //////////////

    function profileProxy() {

        var data = {
            serverURI: ""
        }


        return {

            $get: function ($http, baseProxy) {

                var data = baseProxy.Global.data.serverMF + '/Account';
                ///////////////////////START DONE///////////////////////////////////////////////////////
                function _acceptMessage(obj) {
                    return $http.post(data + "/Message?MessageID=" + obj.MessageID + "&MessagesStatus=" + obj.Status + "&ProjectID=" + obj.record.projectId + "&ProjectName=" + obj.record.projectName);

                };
                function _GetMessageNum() {
                    return $http.get(data + "/CountMessages");
                };
                
                function _GetMessages() {

                    return $http.get(data + "/GetMessages");

                };
                function _GetMessage(messageId) {

                    return $http.get(data + "/Message?MessageID=" + messageId);
                };
               
                function _loadCurrentProfile() {
                    return $http.get(ROOT_ADDR.SYSTEM_ACCOUNT_API + "/Account/Profile");
                };
              
        
                //interface
                return {
                    acceptMessage: _acceptMessage,
                    GetMessageNum:_GetMessageNum,
                    GetMessages: _GetMessages,
                    GetMessage: _GetMessage,
                    loadCurrentProfile: _loadCurrentProfile
           




                };
            }
        }
    }
})(angular);