/*
	@license Angular Treeview version 0.1.6
	ⓒ 2013 AHN JAE-HA http://github.com/eu81273/angular.treeview
	License: MIT


	[TREE attribute]
	angular-treeview: the treeview directive
	tree-id : each tree's unique id.
	tree-model : the tree model on $scope.
	node-id : each node's id
	node-label : each node's label
	node-children: each node's children

	<div
		data-angular-treeview="true"
		data-tree-id="tree"
		data-tree-model="roleList"
		data-node-id="roleId"
		data-node-label="roleName"
		data-node-children="children" >
	</div>
*/

(function ( angular ) {
	'use strict';

	angular.module('angularTreeview', []).directive('treeModel', ['$compile', '$state', 'siteProxy', 'mainRouter', 'mainProvider', function ($compile, $state, siteProxy, mainRouter, mainProvider) {
		return {
			restrict: 'A',
			link: function (scope, element, attrs) {

			    var siteID = $state.params.siteId
			    //tree loc
			    var treeLoc = attrs.treeLoc;
				//tree id
				var treeId = attrs.treeId;
			
				//tree model
				var treeModel = attrs.treeModel;

				//node id
				var nodeId = attrs.nodeId || 'id';

			    //node privi
				var privilige = attrs.nodePrivilige=='true'; //chack if modify
				scope.te = !privilige;
				//node label
				var nodeLabel = attrs.nodeLabel || 'label';

				//children
				var nodeChildren = attrs.nodeChildren || 'children';

				


				//tree template
				var template =
					'<ul>' +
						'<li data-ng-repeat="node in ' + treeModel + '">' +
							'<i class="collapsed" data-ng-show="node.collapsed" data-ng-click="selectNodeHead(node)"></i>' +
							'<i class="expanded" data-ng-show="!node.collapsed" data-ng-click="selectNodeHead(node)"></i>' +
							'<span class="Dots_3 maxBreadCrampWidth" data-ng-class="node.selected" data-ng-click="' + treeId + '.selectNodeLabel(node)">{{node.' + nodeLabel + '}}</span>' +
                              '<i ng-if="te" class="navEye fa fa-eye"></i> ' +
							'<div data-ng-hide="node.collapsed" data-node-privilige="{{node.sharingData.roleModify}}" data-tree-id="' + treeId + '" data-tree-model="node.sites" data-node-id=' + nodeId + ' data-node-label=' + nodeLabel + ' data-node-children="node.sites"></div>' +
                           
						'</li>' +
					'</ul>';

				
				//check tree id, tree model
				if( treeId && treeModel ) {
				   
					//root node
					if( attrs.angularTreeview ) {
					
						//create tree object if not exists
						scope[treeId] = scope[treeId] || {};

						//if node head clicks,
						scope.selectNodeHead = scope[treeId].selectNodeHead = scope[treeId].selectNodeHead || function (selectedNode) {

							//Collapse or Expand
						    selectedNode.collapsed = selectedNode.collapsed ? false : true;
						    
						};

						//if node label clicks,
						scope[treeId].selectNodeLabel = scope[treeId].selectNodeLabel || function( selectedNode ){

							//remove highlight from previous node
							if( scope[treeId].currentNode && scope[treeId].currentNode.selected ) {
								scope[treeId].currentNode.selected = undefined;
							}
							if (scope.navbarType == 'menu') {
							    mainProvider.CurrentSite.data.level = selectedNode.sharingData.level;

							}
							//set highlight to selected node
							selectedNode.selected = 'selected';
							
						
							//set currentNode
							scope[treeId].currentNode = selectedNode;
							if (scope.navbarType == 'menu') {
							    $state.go('site.preview.map', { siteId: selectedNode.siteID });
							    mainRouter.callkey("choosenSiteId", selectedNode.siteID);
							} else if(scope.navbarType == 'checkbox') {  // transfer that site
							    scope.$parent.$parent.targetSiteTransfer = selectedNode.siteID;
							}else if(scope.navbarType == 'alerts'){
							    mainRouter.callkey("treeAlertForSiteID", selectedNode.siteID);
							}
							
						};
					}

					//Rendering template.
					element.html('').append($compile(template)(scope));
					
				}
			}
		};
	}]);
})( angular );
