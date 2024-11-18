
var reliPort = 104;
var ROOT_ADDR = {

    SYSTEM_ACCOUNT_ROOT: "http://localhost:54790",
    SYSTEM_MF_ROOT: "http://localhost:54000",
    SYSTEM_XCI_ADMIN_ROOT: "http://localhost:61396",
    //SYSTEM_ACCOUNT_ROOT: "http://account.glc-service.com",
    //SYSTEM_MF_ROOT: "http://MF.glc-service.com",
    //SYSTEM_XCI_ADMIN_ROOT: "http://localhost:61396",
    /*******************************************************************/

   // SYSTEM_ACCOUNT_API: "http://192.168.2."+reliPort+":10801/api", //local
    //SYSTEM_ACCOUNT_API: "http://bs.eitanr.com:10801/api", // outer
     SYSTEM_ACCOUNT_API: "http://account.glc-service.com/API/api" ,//rnd

    // XCI_API: "http://192.168.2." + reliPort + ":10802/api", // local
    //XCI_API: "http://bs.eitanr.com:10802/api", // outer
    XCI_API: "http://MF.glc-service.com/XCI-API/api", //rnd


    // MF_API: "http://192.168.2." + reliPort + ":10800/api" //local
    // MF_API: "http://bs.eitanr.com:10800/api" //outer
     MF_API: "http://MF.glc-service.com/MF-API/api", //rnd
     

     ONLINE_SERVER: "http://localhost:3003"
     //ONLINE_SERVER: "http://online.cheers2.net:3003"
    // ONLINE_SERVER: "http://online.glc-service.com:3003"
};

var MAIN_LINKS = {
    PROFILE: { link: ROOT_ADDR.SYSTEM_ACCOUNT_ROOT_INDEX + "/Account/index.html#/profile" },
    LOGIN: { link: ROOT_ADDR.SYSTEM_ACCOUNT_ROOT_INDEX + "/login.html?box=login" },
    ACCOUNT_APP_LIST: { link: ROOT_ADDR.SYSTEM_ACCOUNT_ROOT_INDEX + "/login.html?box=app" },
   
}

//////////////////////////////////////////////////////
//SYSTEM_ACCOUNT
var ACCOUNT_LOGIN_URI = {
    "systemName": "System_Account",
    "BaseUrl": ROOT_ADDR.SYSTEM_ACCOUNT_ROOT_INDEX + "/Account/index.html#/admin/users",
    "ImageSrc": "Login/img/user-management-.png",
    "Title": "Users Administration ",
    "SubTitle": "Users Administration System"
}
//SYSTEM_MF
var MF_ROOT_URI = {
    "systemName": "System_MF",
    "BaseUrl": ROOT_ADDR.SYSTEM_MF_ROOT,
    "ImageSrc": "Login/img/MF-CloudBased.png",
    "Title": "Cloud Based Control",
    "SubTitle": "Cyber-Rain UI"
}
//SYSTEM_XCI_ADMIN
var XCI_ADMIN = {
    "systemName": "System_XCI-Admin",
    "BaseUrl": ROOT_ADDR.SYSTEM_XCI_ADMIN_ROOT + "/index.html#/admin",
    "ImageSrc": "Login/img/XCI-Admin.png",
    "Title": "Cyber-Rain Admin",
    "SubTitle": "CR Administration System"
}
//SYSTEM_GSI_ADMIN
var GSI_ADMIN = {
    "systemName": "System_GSI-Admin",
    "BaseUrl": ROOT_ADDR.SYSTEM_ACCOUNT_ROOT_INDEX + "/Gsi.html",
    "ImageSrc": "Login/img/GSI-Admin.png",
    "Title": "GSI Admin",
    "SubTitle": "GSI Administration System"
}

var SMALL_VIEW = 767;





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

