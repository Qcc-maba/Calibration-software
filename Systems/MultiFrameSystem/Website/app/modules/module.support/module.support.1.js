(function (angular) {
	'use strict';

	//////////////// AngularJS //////////////
	angular.module('module.support', ["ui.router"])
		.config(['$stateProvider', '$urlRouterProvider',function ($stateProvider, $urlRouterProvider) {
		$stateProvider
		  .state('support', {
		  	url: '/support',
		  	views: {
		  		'root@': {
		  			template: '<div support></div>',
		  			controller: function () {

		  			    $("#splash-page").css("display", "none");
		  			    closeNavbar();
		  			}
		  		}

		  	}
		  })

	}]);

})(angular);





