
(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.accessories')
        .provider('coordinator', coordinator);


    //////////////// JavaScript //////////////

    function coordinator() {

        var bus = [];

        function seachForBus(busName) {
            for (var i = 0; i < bus.length; i++) {
                if (bus[i].busName == busName) {
                    return bus[i];
                }
            }

            var newBus = {
                busName: busName,
                subscribers: []
            };

            bus.push(newBus);

            return newBus;
        }

        function ClearSubscription(eventName) {

            var bus = seachForBus(eventName);
            bus.subscribers = [];
        }

        function SubscribeEvent(eventName, callback) {

            var bus = seachForBus(eventName);
            bus.subscribers.push(callback);
        }
      
        function PublishEvent(eventName, obj) {
            var event = {
                eventName: eventName,
                data: obj                
            };

            var bus = seachForBus(eventName);

            for (var i = 0; i < bus.subscribers.length; i++) {
                bus.subscribers[i](event);
            }
        }

        return {
            $get: function ($http, baseProxy) {

   

                //interface
                return {
                    PublishEvent: PublishEvent,
                    SubscribeEvent: SubscribeEvent,
                    ClearSubscription: ClearSubscription
                };
            }
        }
    }
})(angular);