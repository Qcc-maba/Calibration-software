
(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.main')
        .provider('mainRouter', mainRouter);


    //////////////// JavaScript //////////////


    function mainRouter() {


        return {
            $get: function () {
              
                var callbacks = [];

                //********************************************
                function _register(description, fn) {
                    var obj =null;
                    for (var i = 0; i < callbacks.length; i++) {
                        if (callbacks[i].key == description) {
                            obj =  callbacks[i]
                        }
                    }
                    if (obj) {
                        obj.callback = fn;
                    } else {
                        callbacks.push({ callback: fn, key: description })
                    }
                

           
                }

                //********************************************
                function _callkey(description,data) {
                    for (var i = 0; i < callbacks.length;i++) {
                        if (callbacks[i].key == description) {
                            return callbacks[i].callback(data)
                        }
                    }
                }

               

                //interface
                return {
                    register: _register,
                    callkey:_callkey
                };
            }
        }
    }
})(angular);