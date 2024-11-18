
(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.accessories')
        .provider('directiveComm', directiveCommFactory);


    //////////////// JavaScript //////////////
    function directiveCommFactory() {

        function Connector() {

        }

        Connector.prototype.lastArguments_Up = null;
        Connector.prototype.lastArguments_Down = null;

        Connector.prototype.CallbackUp = function () {
            this.lastArguments_Up = arguments;

            if (this._CallbackUp) {
                return this._CallbackUp.apply(this, this.lastArguments_Up);
            }
        }
        Connector.prototype.CallbackDown = function () {

            this.lastArguments_Down = arguments;

            if (this._CallbackDown) {
                return this._CallbackDown.apply(this, this.lastArguments_Down);
            }

        }
        Connector.prototype.SetCallbackUp = function (callback) {
            this._CallbackUp = callback;

            if (this.lastArguments_Up) {
                return callback.apply(this, this.lastArguments_Up);
            }
        }
        Connector.prototype.SetCallbackDown = function (callback) {
            this._CallbackDown = callback;

            if (this.lastArguments_Down) {
                return callback.apply(this, this.lastArguments_Down);
            }
        }


        function _CreateConnector() {

            return new Connector();
        }


        return {
            $get: function ($http, baseProxy) {



                //interface
                return {
                    CreateConnector: _CreateConnector
                };
            }
        }
    }
})(angular);
