(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.device')
        .directive('adviserDirective', adviserDirectiveFactory);
    /***********************************************************************************************************************************************************************/
    function adviserDirectiveFactory() {
        return {
            restrict: 'EA',
            scope: {
                comm: '=' 
            },
            templateUrl: 'app/modules/module.device/adviser/adviser.html',

            controller: ['$scope', 'zoneProxy', '$stateParams', 'mainRouter', '$filter', function ($scope, zoneProxy, $stateParams, mainRouter, $filter) {
                $scope.deviceId = $stateParams.deviceId;
                $scope.zoneId = $stateParams.zoneId;
                $scope.hideRecLink = true;
                //**************************************Attribute******************************
                
                $scope.ladda = {
                    "acceptSeggestion": false,
                    "plantType": false,
                    "sprinklerType":false,
                    "slopeType":false,
                    "soilType":false,
                    "sunExposureType": false 
                }
           
                //***************************************Functions******************************
                //************************************************SetCallbackUp(scheduleConnector)******************************
                $scope.comm.SetCallbackDown(function (obj) {
                    $scope.adviser = {
                        categories : obj.categories,
                        suggestions: {},
                        current:{
                           
                        }
                    }

                    showRecomendation();
                  
                });

                
                mainRouter.register("showRecomendationEvent", function (data) {
                    showRecomendation();
                });

                var showRecomendation = function () {
                    zoneProxy.getIrrigationSuggestion($scope.deviceId, $scope.zoneId)
                             .success(function (data) {
                                 data = data.body;
                                 $scope.adviser.suggestions.suggestion_TotalWeeklyMinutes = data.suggestion_TotalWeeklyMinutes;
                                 $scope.adviser.suggestions.suggestion_TotalWeeklyDays = data.suggestion_TotalWeeklyDays;
                                 $scope.adviser.suggestions.suggestion_MaximumCycleMinutes = data.suggestion_MaximumCycleMinutes;
                                 $scope.adviser.suggestions.suggestion_SoakTimeMinutes = data.suggestion_SoakTimeMinutes;

                                 //**************************************
                                 if (data.scheduleType=='Weekly') {
                                     $scope.tableType = 'Weekly';
                                    
                                 }
                                 $scope.adviser.current.current_TotalWeeklyMinutes = data.current_TotalWeeklyMinutes;
                                 $scope.adviser.current.current_WateringDays = data.current_WateringDays;
                                 $scope.adviser.current.maxCycleTime = data.maxCycleTime;
                                 $scope.adviser.current.maxSoakTime = data.maxSoakTime;
                            
                                
                             }).error(function (data, status, headers, config) {
                                 toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));

                             });

                }
              
                //***********************************************************AcceptSuggestions(Outer)***********************************
                $scope.AcceptSuggestions = function () {
                    $scope.showHideRecommendation = false;
                    $scope.ladda.acceptSeggestion = true;
                    zoneProxy.acceptSuggestions($scope.deviceId, $scope.zoneId)
                            .success(function (data) {
                                data = data.body;
                                mainRouter.callkey("refreshZonePage", {});
                                $scope.closeAdviser();
                                toastr.success($filter('translate')('successChanges'), $filter('translate')('Success'));
                                $scope.ladda.acceptSeggestion = false;

                            }).error(function (data, status, headers, config) {
                                toastr.error($filter('translate')('toastrErrMsgGet'), $filter('translate')('Error'));

                            });
                }
                //**********************************************************changeSelected(Outer)***************************************
                $scope.changeSelected = function (type, newSelected) {
                    //@@@@@
                    //send to server and get sugesstion from service?????????????
                    
                   
                    ///**************sucsses*******************************
                    $scope.adviser.suggestions.isAccepted = false;
                    $scope.adviser.categories[type].selected = newSelected;
                    $scope.adviser.service = "changeSelected";
                    $scope.ladda[type] = true;
                    $scope.ladda[type] = false;
                    
                }
                //*********************************************************************************************
                $scope.closeAdviser = function () {
                    $('.adviserBigImgFrame').css("display", "none");
                }
                //*********************************************************************************************
                $scope.openAdviser = function () {
                    $('.adviserBigImgFrame').css("display", "block");
                }
              //*********************************************************************************************
                $scope.getSelectedType = function (Type , number) {
                    $scope.choosenType = $scope.adviser.categories[Type];
                    $scope.choosenTypeNumber = number;
                    $scope.openAdviser();
                }
                //*********************************************************************************************
                $scope.getSelectedSubType = function (subTypeSelected) {
                    $scope.choosenType.selected = subTypeSelected;
                    $scope.saveAndGetRecommendation();
                }
                //*********************************************************************************************
                //$scope.blinkingDivOpen = function () {
                //    $("#blinkingDiv").css( "display","block" );
                //}
                ////*********************************************************************************************
                //$scope.blinkingDivClose = function () {
                //    $("#blinkingDiv").css("display", "none");
                //}
                //*********************************************************************************************
                $scope.saveAndGetRecommendation = function () {
               
                    var types = [];
                    types.push({
                        typeID: $scope.adviser.categories.plantType.advisorTypeID,
                        subTypeID: $scope.adviser.categories.plantType.selected.typeID,
                        customValue: $scope.adviser.categories.plantType.selected.isCustom ? $scope.adviser.categories.plantType.selected.value : null
                    });
                    types.push({
                        typeID: $scope.adviser.categories.slopeType.advisorTypeID,
                        subTypeID: $scope.adviser.categories.slopeType.selected.typeID,
                        customValue: $scope.adviser.categories.slopeType.selected.isCustom ? $scope.adviser.categories.slopeType.selected.value : null
                    });
                    types.push({
                        typeID: $scope.adviser.categories.soilType.advisorTypeID,
                        subTypeID: $scope.adviser.categories.soilType.selected.typeID,
                        customValue: $scope.adviser.categories.soilType.selected.isCustom ? $scope.adviser.categories.soilType.selected.value : null
                    });
                    types.push({
                        typeID: $scope.adviser.categories.sprinklerType.advisorTypeID,
                        subTypeID: $scope.adviser.categories.sprinklerType.selected.typeID,
                        customValue: $scope.adviser.categories.sprinklerType.selected.isCustom ? $scope.adviser.categories.sprinklerType.selected.value : null
                    });
                    types.push({
                        typeID: $scope.adviser.categories.sunExposureType.advisorTypeID,
                        subTypeID: $scope.adviser.categories.sunExposureType.selected.typeID,
                        customValue: $scope.adviser.categories.sunExposureType.selected.isCustom ? $scope.adviser.categories.sunExposureType.selected.value : null
                    });
                    zoneProxy.saveAndGetRecommendation($scope.deviceId, $scope.zoneId, types)
                        .success(function (data) {
                            $scope.openRecomendation();
                           
                            $scope.ladda.byZone = false;
                            data = data.body;
                            $scope.adviser.suggestions.suggestion_TotalWeeklyMinutes = data.suggestion_TotalWeeklyMinutes;
                            $scope.adviser.suggestions.suggestion_TotalWeeklyDays = data.suggestion_TotalWeeklyDays;
                            $scope.adviser.suggestions.suggestion_MaximumCycleMinutes = data.suggestion_MaximumCycleMinutes;
                            $scope.adviser.suggestions.suggestion_SoakTimeMinutes = data.suggestion_SoakTimeMinutes;
                            $scope.adviser.current.current_TotalWeeklyMinutes = data.current_TotalWeeklyMinutes;
                            $scope.adviser.current.current_WateringDays = data.current_WateringDays;
                            $scope.adviser.current.maxCycleTime = data.maxCycleTime;
                            $scope.adviser.current.maxSoakTime = data.maxSoakTime;
                        });
         
                    
                  
                }
                //*********************************************************************************************
                $scope.openRecomendation = function () {
                    $scope.hideRecLink = false;
                    $scope.showHideRecommendation = true;
                }
               // *********************************************************************************************
                $scope.closeRecomendation = function () {
                    $scope.hideRecLink = true;
                    $scope.showHideRecommendation = false;
                }
            }],
            //************************************************link***************************************
            link: function (scope, element, attrs, ngModel) {
               
            }
        };//return
    }
})(angular);
