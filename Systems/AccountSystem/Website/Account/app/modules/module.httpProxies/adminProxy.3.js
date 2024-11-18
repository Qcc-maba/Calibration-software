
(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.httpProxies')
        .provider('adminProxy', adminProxy);


    //////////////// JavaScript //////////////

    function adminProxy() {



        return {

            $get: function ($http, baseProxy) {

                var data = baseProxy.Global.data.serverUri + '/Account/Profile';
                var timeZone = baseProxy.Global.data.serverUri + '/Types';
                ///////////////////////START DONE///////////////////////////////////////////////////////

                function _loadCurrentProfile() {
                    return $http.get(data);
                };

                function _getUsersKit() {
                    return $http.get(timeZone + "/All");
                };

                //function _getUserImage(userID) {
                //    return buildUri("GetUserImage/?UserID=" + (userID || 1), true);
                //};

                function _SaveCurrentProfile(userData) {
                    return $http.post(data, userData);
                };
                function _resetPassword(data) {
                    return $http.post(baseProxy.Global.data.serverUri + "/Account/ResetPassword", data);
                };

                //user administretion
                function _getallUsers(search, pageNumber, pageSize) {
                    return $http.get(baseProxy.Global.data.serverUri + "/Admin/Users?search="+search+"&pageNumber="+pageNumber+"&PageSize="+pageSize);
                };
                function _getUser(email) {
                    return $http.get(baseProxy.Global.data.serverUri + "/Admin/User?UserEmail=" + email);
                };
                function _getUIFormats() {
                    return $http.get(baseProxy.Global.data.serverUri + "/Types/UIFormats");
                };
                function _setUIFormat(email,id) {
                    return $http.post(baseProxy.Global.data.serverUri + "/Admin/User/UIFormat?UserEmail="+email+"&NewUIFormatID="+id);
                };
                function _resetPass(obj) {
                    return $http.post(baseProxy.Global.data.serverUri + "/Admin/User/Password",obj);
                };
                function _lockUnLock(email,bool) {
                    return $http.post(baseProxy.Global.data.serverUri + "/Admin/User/Lockout?UserEmail="+email+"&Lockout="+bool);
                };
                function _delUser(email) {
                    return $http.delete(baseProxy.Global.data.serverUri + "/Admin/User?UserEmail="+email);
                };
                function _getUserRoles(email) {
                    return $http.get(baseProxy.Global.data.serverUri + "/Admin/User/Roles?UserEmail="+email);
                };
                function _setUserRoles(email, obj) {
                    return $http.post(baseProxy.Global.data.serverUri + "/Admin/User/Roles?UserEmail=" + email, obj);
                };
                //interface
                return {
                    loadCurrentProfile: _loadCurrentProfile,
                    SaveCurrentProfile: _SaveCurrentProfile,
                    getUsersKit: _getUsersKit,
                    resetPassword: _resetPassword,
                    getallUsers: _getallUsers,
                    getUser: _getUser,
                    getUIFormats: _getUIFormats,
                    setUIFormat: _setUIFormat,
                    resetPass: _resetPass,
                    lockUnLock: _lockUnLock,
                    delUser: _delUser,
                    getUserRoles: _getUserRoles,
                    setUserRoles: _setUserRoles
                };
            }
        }
    }
})(angular);