
(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.main')
        .provider('user', user);


    //////////////// JavaScript //////////////
    

   function user() {

      
        return {
            $get: function (profileProxy) {
                var _currentUser = {
                    info: {
                       
                    }

                }
                var _messages = {
                    messageNum: 0,
                    messagesList:''
                }
                var _userAndSite = {
                    siteID:'',
                    sharingData: {},
                    
                }
                //*******************************************
                function _saveSharingData(siteID, sharingData) {
                    _userAndSite.siteID = siteID;
                    _userAndSite.sharingData = sharingData;

                }
                //*******************************************
                function _getSharingData() {
                   
                    return _userAndSite;

                }
                //********************************************
                function getMessagesInfo() {
                    profileProxy.GetMessageNum()
                   .success(function (data) {
                       _messages.messageNum = data.body;

                   });
                }

                //********************************************
                function _getUser() {
                    return _currentUser;
                }
                //*****************************************
                function _setUser(data) {
                    _currentUser.info = data;
                }
                //******************************************
                function _reload() {
                    getMessagesInfo();
                  
                }

                _reload();

                //interface
                return {
                 
                    setUser: _setUser,
                    getUser:_getUser,
                    Messages: _messages,
                    saveSharingData: _saveSharingData,
                    getSharingData:_getSharingData,
                    reload: _reload              
                };
            }
        }
    }
})(angular);