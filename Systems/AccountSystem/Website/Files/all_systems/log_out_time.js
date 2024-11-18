
var WD_Time = new Date().getTime();
var LastClickParam1="";
var LastClickParam2 = "";
var LastAction = "sssss";


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
function fixLoadingOn() {
        document.getElementById("fixLoading").style.display = "block";
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

