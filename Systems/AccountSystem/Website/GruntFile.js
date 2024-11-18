//https://www.youtube.com/watch?v=TMKj0BxzVgw



module.exports = function (grunt) {



    grunt.initConfig({
        //*********************************************************************************concat*******************
        copy: {
            main: {
                files: [
                  // includes files within path and its sub-directories
                  { expand: true, src: ['Content/**'], dest: 'release/' },

                ],
            },
        },

        concat: {
            //*********css concat
            css_general_list: { //all systems
                src: ['Files/release_js/jquery/jquery-ui.min.css'
                     , "Files/vendor/bootstrap/bootstrap.css"
                     , "Files/vendor/bootstrap/switch/bootstrap-switch.css"
                     , "Files/vendor/release_css/fonts/font-awesome/font-awesome.css"
                     , "Files/vendor/release_css/fonts/style.css"
                     , "Files/vendor/general/toastr/toastr.css"
                     , "Files/vendor/jquery-ui/jquery-ui.css"
                     , "Files/vendor/bootstrap/timepicker/bootstrap-clockpicker.css"
                     , "Files/vendor/bootstrap/colorpicker/colorpicker.css"
                     , "Files/vendor/ladda/ladda-themeless.min.css"
                ],
                dest: "release/Account/css/css_general_list.css"
            },
            css_template_list: { //all systems
                src: ["Files/content/css/main.css"
                     ,"Files/content/css/main-responsive.css"
                     ,"Files/content/css/generalCss.css"],
                dest: "release/Account/css/css_template_list.css"
            },
            css_my: {
                src: [ "Files/content/css/account.css"
                     , "Files/content/css/theme_light.css"],
                dest: "release/Account/css/css_my.css"
            },
            css_login: { //login
                src: [
                       "Files/vendor/bootstrap/bootstrap.css"
                     , "Files/content/css/main-responsive.css"
                     , "Files/vendor/ladda/ladda-themeless.min.css"
                     , "Files/content/css/login/mainLogin.css"
                     , "Files/content/css/login/login.css"
                 
                ],
                dest: "release/css/all_login_css.css"
            },
            

            //***********js concat
            js_general_apps: {
                src: [
                  'Files/all_systems/ServiceURI.js'
                , 'Files/all_systems/log_out_time.js'
                ],
                dest: 'release/Account/js/general_apps_all.js'
            },
            js_general_Login_apps: {
                src: [
                  'Files/all_systems/ServiceURI.js'
                , 'Files/all_systems/log_out_time.js'
                ],
                dest: 'release/js/general_apps_all.js'
            },
       
            js_general_vendor: {
                src: [
                    'Files/vendor/jquery/jquery-2.1.3.min.js'
                    , 'Files/release_js/jquery/jquery-ui.min.js'
                    , 'Files/vendor/bootstrap/bootstrap.min.js'
                    , 'Files/vendor/bootstrap/switch/bootstrap-switch.min.js'
                    , 'Files/vendor/general/perfect-scrollbar.min.js'
                    , 'Files/vendor/angular/angular.js'
                    , 'Files/vendor/angular-ui/angular-ui-router.js'
                    , 'Files/vendor/angular/angular-messages.min.js'
                    , 'Files/vendor/angular/angular-sanitize.min.js'
                    , 'Files/vendor/general/toastr/toastr.min.js'
                    , "Files/content/js/jqueryInit.min.css"
                    , 'Files/vendor/ladda/spin.min.js'
                    , 'Files/vendor/ladda/ladda.min.js'
                    , 'Files/vendor/ladda/prism.js'
                    , 'Files/vendor/ladda/spin.min.js'
                    , 'Files/vendor/ladda/laddaDirective.js'
                ],
                dest: 'release/Account/js/vendor_js_all.js'
            },
      
            js_general_translate: {   //all systems except login
                src: [
                      "Files/content/angular_general_modules/module.translate/angular-translate.js",
                      "Files/content/angular_general_modules/module.translate/angular-translate-loader-static-files.js",
                      "Files/content/angular_general_modules/module.translate/tmhDynamicLocale.js"
            ],
                dest: 'release/js/translate_js_all.js'
            },
        
            js_app: {  
                src: ["Account/app/**/*.1.js"
                    , "Account/app/**/*.2.js"
                    , "Account/app/**/*.3.js"
                    , "Account/app/app.js"
                      
                ],
                dest: 'release/Account/js/js_app.js'
            }
            , js_login: {
                src: [
                    'Files/vendor/jquery/jquery-2.1.3.min.js'
                    , 'Files/vendor/bootstrap/bootstrap.min.js'
                    , 'Files/vendor/ladda/spin.min.js'
                    , 'Files/vendor/ladda/ladda.min.js'
                    , 'Files/vendor/ladda/prism.js'
                    , 'Files/vendor/ladda/spin.min.js'
                    , 'Files/vendor/jquery/jquery.validate.js'
                    , 'loginJs/login.js'
                    , 'loginJs/MyTranslateGeneral.js'
                   
                  
                ],
                dest: 'release/js/all_login_js.js'
            }
        },
        //*****************************************annonate**********************************************************************
        ngAnnotate: {
            options: {
               singleQuotes: true
            },
             app: {
               files: {
                   'release/Account/js/js_app.annonate.js': ['release/Account/js/js_app.js']
          
              }
            }
        },
        //*****************************************uglify****************************************************************
        uglify:{
            js_general_apps: {
                src: 'release/Account/js/general_apps_all.js',
                dest: 'release/Account/js/general_apps_all.min.js'
            },
            js_general_translate: {
                src: 'release/Account/js/translate_js_all.js',
                dest: 'release/Account/js/translate_js_all.min.js'
            },
            js_app: {
                src: 'release/Account/js/js_app.annonate.js',
                dest: 'release/Account/js/js_app.annonate.min.js'
            },
            js_login: {
                src: 'release/js/all_login_js.js',
                dest: 'release/js/all_login_js.min.js'
            }
        }
        ,
        html2js: {
            options: {
                base: '../Website/Account/',
                module: 'myApp.templates',
                singleModule: true,
                useStrict: true,
                htmlmin: {
                    collapseBooleanAttributes: true,
                    collapseWhitespace: true,
                    removeAttributeQuotes: true,
                    removeComments: true,
                    removeEmptyAttributes: true,
                    removeRedundantAttributes: true,
                    removeScriptTypeAttributes: true,
                    removeStyleLinkTypeAttributes: true
                }
            },
            main: {
                src: ['Account/app/**/*.html'],
                dest: 'release/Account/js/templates.js'
            }
        }
        ,
        //***************************************css min*******************************************************************
        cssmin: {
            css_general_list: { //all systems
                src: 'release/Account/css/css_general_list.css',
                dest: 'release/Account/css/css_general_list.min.css'
        },
            css_template_list: {//all systems
                src: 'release/Account/css/css_template_list.css',
                dest: 'release/Account/css/css_template_list.min.css'
            },
            css_my: {
                src: 'release/Account/css/css_my.css',
                dest: 'release/Account/css/css_my.min.css'
            },
            css_login: {
                src: 'release/css/all_login_css.css',
                dest: 'release/css/all_login_css.min.css'
           }
        }

        //**********************************************************************
        
        
       

       
    });

    grunt.loadNpmTasks('grunt-html2js');
    grunt.loadNpmTasks('grunt-contrib-concat');
    grunt.loadNpmTasks('grunt-contrib-uglify');
    grunt.loadNpmTasks('grunt-contrib-cssmin');
    grunt.loadNpmTasks('grunt-ng-annotate');
    grunt.loadNpmTasks('grunt-contrib-copy');
    grunt.registerTask('default', ['copy','html2js','concat', 'ngAnnotate', 'cssmin', 'uglify']);   //, 'watch'
};

//For defaule Task       run: grunt          
//For watch              run: grunt watch   // that service will run forever and run the specify tasks for any save according to relevant file . we run grunt watch before working
//For concatenate        run: grunt concat
//For uglify             run: grunt uglify
//For cssmin             run: grunt cssmin
//For build all commands run: grunt build