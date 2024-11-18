
var WD_Time = new Date().getTime();
var LastClickParam1="";
var LastClickParam2 = "";
var LastAction = "sssss";
const MAXIRRIGATION_TIME = 255;

String.prototype.isNumeric = function () {
    return !isNaN(this.valueOf() * 1);
};
function clearTimeWD() {
    WD_Time = new Date().getTime();
}

out = setInterval(function () {
    var now = new Date().getTime();
    var def = (now - WD_Time) / 60000   //min
    if (def >= 30) {
        clearInterval(out);
        if (window.location.href.indexOf("login") == -1) {
         //   window.location = MAIN_LINKS.LOGIN.link + "&returnUrl=" + encodeURIComponent(window.location.href);
        }
    }
}, 60000) //1 minutes interval

function setLastAction(action) {
    LastAction = action;
}
function fixLoadingOn(action,param1,param2) {
    
    var bool = false;
    switch (action) {
        case "goToSite":
            if (param2 !=LastClickParam2) {
                bool = true;
            }
            break;
        case "goToDevice":
            if (param1 != LastClickParam1) {
                bool = true;
            }
            break;


        case "PSettings":
        case "PMap":
        case "PSquares":
        case "SList":
        case "SGeneral":
        case "SCharts":
        case "settings":
        case "DView":
        case "DOnline":
        case "GoogleMapManual":
        case "GoogleMapAuto":
        case "Login":
        case "Profile":
        case "ZoneSettings":
        case "ZoneAdviser":
        case "ZoneOddAdviser":
  
        
            if (action != LastAction) {
                bool = true;
            }
            break;

        case "DZones":
            if (param1 != LastClickParam1) {
                bool = true;
            }
            break;
  
            
       
    }
    if (bool) {
        document.getElementById("fixLoading").style.display = "block";
       
    }
    LastClickParam1 = param1;
    LastClickParam2 = param2;
    LastAction = action;
}
function fixLoadingOff() {
    document.getElementById("fixLoading").style.display = "none";
    
}

function closeNavbar() {
 
        $(".main-content").css("margin-left", "0px");
        $("#MyNavbar").hide();
        $("#dragbar").hide();
        $(".navbar-content").hide();
   
}

function openNavbar() {
    if (window.innerWidth > 768){
        $(".main-content").css("margin-left", "225px");
        $("#dragbar").show();
        $("#MyNavbar").show();
        $(".navbar-content").show();
}
}
function addScrollToSmallViewBody() {
    $('html').css({
        'overflow': 'auto',
        'height': 'auto'
    });
    $('#openSmallMenue').css({ 'display': 'block' });
    $('.overlay').css({ 'display': 'none' });
   
    
}
function removeScrollToSmallViewBody() {
    $('html').css({
        'overflow': 'hidden',
        'height': '100%'
    });
    
    $('.overlay').css({'display': 'block'});
    $('#openSmallMenue').css({'display': 'none'});
}


