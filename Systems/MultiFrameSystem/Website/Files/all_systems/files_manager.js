

var css_general_list = [
                      "Files/vendor/bootstrap/bootstrap.css",
                      "Files/vendor/bootstrap/switch/bootstrap-switch.css",
                      "Files/vendor/fonts/font-awesome/font-awesome.css",
                      "Files/vendor/fonts/style.css",
                      "Files/vendor/general/toastr/toastr.css",
                      "Files/vendor/jquery-ui/jquery-ui.css",
                      "Files/vendor/bootstrap/timepicker/bootstrap-clockpicker.css",
                      "Files/vendor/bootstrap/colorpicker/colorpicker.css"
];

var css_template_list = [
                      "Files/content/css/main.css",
                      "Files/content/css/main-responsive.css",
                      "Files/content/css/generalCss.css"
];

var js_general_list = [
                      "Files/vendor/jquery/jquery-2.1.3.js",
                      "Files/vendor/bootstrap/bootstrap.js",
                      "Files/vendor/bootstrap/switch/bootstrap-switch.js",
                      "Files/vendor/general/perfect-scrollbar.js",
                      "Files/vendor/angular/angular.js",
                      "Files/vendor/angular-ui/angular-ui-router.js",
                      "Files/vendor/angular/angular-messages.js",
                      "Files/vendor/angular/angular-sanitize.js",
                      "Files/vendor/general/toastr/toastr.js"
];

var js_MF_list = [
                      "Files/vendor/jquery-ui/jquery-ui.js",
                      "Files/vendor/bootstrap/colorpicker/bootstrap-colorpicker-module.js",
];

var js_translate = [
    "Files/content/angular_general_modules/module.translate/module.translate.js",
    "Files/content/angular_general_modules/module.translate/translateProvider.js",
    "Files/content/angular_general_modules/module.translate/angular-translate.js",
    "Files/content/angular_general_modules/module.translate/angular-translate-loader-static-files.js",
    "Files/content/angular_general_modules/module.translate/tmhDynamicLocale.js"
]





var createDynamicTag = function (arr, tagName, beforID) {
    var Before = document.getElementById(beforID);
    if (tagName == 'script') {
        arr.forEach(function (entry) {

            document.write('<script type="text/javascript" src="' + ROOT_ADDR.SYSTEM_LOGIN_ROOT + "/" + entry + '"></script>');
        });

    } else {//link
        arr.forEach(function (entry) {
            var link = document.createElement('link');
            link.href = ROOT_ADDR.SYSTEM_LOGIN_ROOT + "/" + entry;
            link.rel = "stylesheet"
            Before.parentNode.insertBefore(link, Before);

        });
    }

}