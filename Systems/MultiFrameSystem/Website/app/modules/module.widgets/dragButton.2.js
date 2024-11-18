//**************************************************NavBar*******************************
$('#dragbar').css({ marginLeft: $('.main-content').css('marginLeft') });
var i = 0;
var dragging = false;
$('#dragbar').mousedown(function (e) {
    e.preventDefault();

    dragging = true;

});

//*********************************************GsiDeviceStatusdragbar**********************
var Statusdragbar = false;



//****************General Mouse Events*****************************
$(document).mousemove(function (e) {
    //******NavBar***************
    if ((dragging) && ($('#dragbar').css("marginLeft") > '224px') && ($('#dragbar').css("marginLeft") < '317px')) {
        $('#dragbar').css("marginLeft", e.pageX + 2);
        $('.navigation-toggler').css("marginLeft", e.pageX - 30);
        $('.tree.menu').css("width", e.pageX + 2);
        $('.main-content').css("marginLeft", e.pageX + 2);
        $('#ghostbar').remove();

    }
    //******GsiDeviceStatusdragbar***********
    if (Statusdragbar) {
        var hanukiyaHeigth = $('.hanukiya').css("height");
        $('.hanukiya').css("height", e.pageY + 2);
    }
});
$(document).mouseup(function (e) {

    //******NavBar***************
    if (dragging) {
        if (($('#dragbar').css("marginLeft") <= '224px')) {
            $('.tree').css("width", '225px');
            $('#dragbar').css("marginLeft", '225px');
            $('.main-content').css("marginLeft", '225px');
            $('.navigation-toggler').css("marginLeft", "190px");
        }
        if (($('#dragbar').css("marginLeft") >= '290px')) {
            $('.tree').css("width", '289px');
            $('#dragbar').css("marginLeft", '289px');
            $('.main-content').css("marginLeft", '289px');
            $('.navigation-toggler').css("marginLeft", "255px");
        }
        dragging = false;
    }
    //******GsiDeviceStatusdragbar***********
    if (Statusdragbar) {
       
        Statusdragbar = false;
    }

    
});