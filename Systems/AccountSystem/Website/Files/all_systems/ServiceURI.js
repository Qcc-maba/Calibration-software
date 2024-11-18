var accountToken = null;
var newToken = null;
var ROOT_ADDR = {

    SYSTEM_MF_ROOT: typeof (Custom_SYSTEM_MF_ROOT) != 'undefined' ? Custom_SYSTEM_MF_ROOT : "https://online.galcon-smart.com",
    SYSTEM_ACCOUNT_API: typeof (Custom_SYSTEM_ACCOUNT__API) != 'undefined' ? Custom_SYSTEM_ACCOUNT__API : "/API"

};

var MAIN_LINKS = {
    PROFILE: { link: "#/profile" },
    LOGIN: { link: "../?box=login" },
    ACCOUNT_APP_LIST: { link: "?box=app" }
}

//////////////////////////////////////////////////////
//SYSTEM_ACCOUNT
var ACCOUNT_LOGIN_URI = {
    "systemName": "System_ACCOUNT_ADMIN",
    "BaseUrl":  "Account#/admin/users",
    "ImageSrc": "../../Content/img/user-management-.png",
    "Title": "Users Administration ",
    "SubTitle": "Users Administration System"
}
//SYSTEM_MF
var MF_ROOT_URI = {
    "systemName": "System_MF",
    "BaseUrl": ROOT_ADDR.SYSTEM_MF_ROOT,
    "ImageSrc": "../../Content/img/MF-CloudBased.png",
    "Title": "Cloud Based Control",
    "SubTitle": "Cyber-Rain UI"
}
//SYSTEM_XCI_ADMIN
var XCI_ADMIN = {
    "systemName": "System_XCI_ADMIN",
    "BaseUrl": ROOT_ADDR.SYSTEM_XCI_ADMIN_ROOT + "/index.html#/admin",
    "ImageSrc": "../../Content/img/XCI-Admin.png",
    "Title": "Cyber-Rain Admin",
    "SubTitle": "CR Administration System"
}
//SYSTEM_GSI_ADMIN
var GSI_ADMIN = {
    "systemName": "System_GSI_ADMIN",
    "BaseUrl": ROOT_ADDR.SYSTEM_ACCOUNT_ROOT + "/Gsi.html",
    "ImageSrc": "../../Content/img/GSI-Admin.png",
    "Title": "GSI Admin",
    "SubTitle": "GSI Administration System"
}

var SMALL_VIEW = 767;



