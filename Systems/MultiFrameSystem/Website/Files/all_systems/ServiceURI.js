var GLOBAL_DATA = {

}

var ROOT_ADDR = {

    SYSTEM_ACCOUNT_ROOT: typeof (Custom_SYSTEM_ACCOUNT__ACCOUNT_ROOT) != 'undefined' ? Custom_SYSTEM_ACCOUNT__ACCOUNT_ROOT : "https://account.galcon-smart.com/Account",
    SYSTEM_LOGIN_ROOT: typeof (Custom_SYSTEM_ACCOUNT__LOGIN_ROOT) != 'undefined' ? Custom_SYSTEM_ACCOUNT__LOGIN_ROOT : "https://account.galcon-smart.com",
    SYSTEM_MF_ROOT: typeof (Custom_SYSTEM_MF_ROOT) != 'undefined' ? Custom_SYSTEM_MF_ROOT : "online.galcon-smart.com",
    SYSTEM_ACCOUNT_API: typeof (Custom_SYSTEM_ACCOUNT__API) != 'undefined' ? Custom_SYSTEM_ACCOUNT__API : "/API",//Eitan new
    //XCI_API: "http://MF.glc-service.com/XCI-API/api", //rnd
    //MF_API: "http://MF.glc-service.com/MF-API/api", //rnd
    MF_API_SERVER: "https://online.galcon-smart.com/API", //new
    XCI_API_SERVER: "https://online.galcon-smart.com/XCI", //xci
 
    ONLINE_SERVER: typeof (Custom_ONLINE_SERVER) != 'undefined' ? Custom_ONLINE_SERVER : "http://online.glc-service.com:3003"
};

var MAIN_LINKS = {
    PROFILE: { link: ROOT_ADDR.SYSTEM_ACCOUNT_ROOT + "#/profile" },
    LOGIN: { link: ROOT_ADDR.SYSTEM_LOGIN_ROOT + "?box=login" },
    ACCOUNT_APP_LIST: { link: ROOT_ADDR.SYSTEM_LOGIN_ROOT + "?box=app" }
}

var SMALL_VIEW = 767;
