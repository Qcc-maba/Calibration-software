(function (angular) {
    'use strict';

    angular.module('module.accessories')
      .directive('generalClick', generalClickFactory);

    /**********************************************************************************************************************************************************************/
    function generalClickFactory() {


        return {
            restrict: 'A',
            link: function (scope, element, attr) {

                //****************************closeMessage*********************************************
                function closeMessage(target) {
                    if (target.parents(".messageSidebar").length || target.hasClass("messageSidebar")) {

                    }
                    else if (target.parents(".openMessage").length) {
                        $('#body').css({ 'overflow-y': 'hidden' });

                        if ($('#page-sidebar').css("right") == "0px") {
                            $('#page-sidebar').css("right", "-500px");
                            //element.removeClass('open');
                        } else {
                            $('#page-sidebar').css("right", "0px");
                            //element.addClass('open');
                        }
                    }
                    else {
                        $('#page-sidebar').css("right", "-500px");
                        $('#users').attr("style", { right: "0px" });
                        if (target.parents('#ToggelApp').length >= 1) {
                            $('#body').css({ 'overflow-y': 'hidden' });
                        }
                        else if (target.parents('#main-navigation-menu').length >= 1 && target.parents('.sub-menu').length < 1) {
                            $('#body').css({ 'overflow-y': 'hidden' });
                        }

                        else {
                            $('#body').css({ 'overflow-y': 'auto' });
                        }

                    }
                }
                //*****************************scrollToDiv*****************************************************
                function scrollToDiv(target) {

                    if (target.parents("#previewList").length || target.parents("#previewMap").length || target.parents("#previewSquares").length) {
                        $('html,body').animate({
                            scrollTop: $("#siteDevicesPanel").offset().top
                        }, 'slow');
                    }
                    if (target[0].id == 'addDeviceGo') {
                        $('html,body').animate({
                            scrollTop: $("#addDeviceModalFooter").offset().top
                        }, 'slow');
                    }




                }
                //****************************closeMessage*********************************************
                function closeSmallMenue(target) {
                    if (target[0].id == 'openSmallMenue') {
                        $('#smallMenue').css({ 'display': "block" });
                    } else if (target.parents(".current-user").length || target.parents(".color").length) {
                        $('#smallMenue').css({ 'display': "block" });
                    }

                    else {
                        $('#smallMenue').css({ 'display': "none" });
                    }
                }

                //**********************************************************************************************

                $("body").click
                (
                  function (e) {
                      var target = $(e.target);
                      //closeMessage(target);
                      //scrollToDiv(target);
                      //closeSmallMenue(target);



                  }
                );

            }
        }

    }
})(angular);