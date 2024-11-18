//https://www.youtube.com/watch?v=TMKj0BxzVgw



module.exports = function (grunt) {



    grunt.initConfig({
        //**********************************************concat*******************

        copy: {
            main: {
                files: [
                  // includes files within path and its sub-directories
                  { expand: true, src: ['content/**'], dest: 'release/' },

                ],
            },
        },
        concat: {
                        //css
                        css_general_list: { 
                            src: [
                                   "Files/vendor/bootstrap/bootstrap.css"
                                 , "Files/vendor/bootstrap/switch/bootstrap-switch.css"
                                 , "Files/vendor/release_css/fonts/font-awesome/font-awesome.css"
                                 , "Files/vendor/release_css/fonts/style.css"
                                 , "Files/vendor/general/toastr/toastr.css"
                                 , "Files/vendor/jquery-ui/jquery-ui.css"
                                 , "Files/vendor/bootstrap/timepicker/bootstrap-clockpicker.css"
                                 , "Files/vendor/bootstrap/colorpicker/colorpicker.css"
                                 , "Files/vendor/ladda/ladda-themeless.min.css"
                                 , "Files/content/css/widgets/jquery.flipcountdown.css"
                                 , "Files/content/css/widgets/clockpicker.css"
                                 , "Files/content/css/widgets/spinner.css"
                                 , "Files/content/css/widgets/timeTo.css"
                                 , "app/modules/module.widgets/tree/css/angular.treeview.css"
                            ],
                            dest: "release/css/css_general_list.css"
                        },
                        css_template_list: {
                            src: [ "Files/content/css/main.css"
                                 , "Files/content/css/main-responsive.css"
                                 , "Files/content/css/generalCss.css"],
                            dest: "release/css/css_template_list.css"
                        },
                        css_MF: {
                            src: ["Files/content/css/MF/myProgressBar.css"
                                 , "Files/content/css/MF/mySplash.css"
                                 , "Files/content/css/MF/myWeatherForcast.css"
                                 , "Files/content/css/MF/onlyMf.css"
                            ],
                            dest: "release/css/mf.css"
                        },
            
                        css_CR: {
                            src: ["Files/content/css/Cyber-Rain/myFlipClock.css"
                                 , "Files/content/css/Cyber-Rain/advizer.css"
                                 , "Files/content/css/Cyber-Rain/cyber-rain.css"
                            ],
                            dest: "release/css/cyber-rain.css"
                        },
                        css_GSI: {
                            src: ["Files/content/css/GSI/hanukiya.css"
                                 , "release/css/gsi.css"
        
                            ],
                            dest: "release/css/gsi.css"
                        },

                       //js
                        js_general_apps: {
                            src: [
                              'Files/all_systems/ServiceURI.js'
                            , 'Files/all_systems/log_out_time.js'
                            ],
                            dest: 'release/js/general_apps_all.js'
                        },
                        js_vendor: {
                            src: [
                                'Files/vendor/jquery/jquery-2.1.3.min.js'
                                , 'Files/vendor/jquery-ui/jquery-ui.min.js'
                                , 'Files/vendor/bootstrap/bootstrap.min.js'
                                , 'Files/vendor/bootstrap/switch/bootstrap-switch.min.js'
                                , 'Files/vendor/general/perfect-scrollbar.min.js'
                                , 'Files/vendor/angular/angular.js'
                                , 'Files/vendor/angular-ui/angular-ui-router.min.js'
                                , 'Files/vendor/angular/angular-messages.min.js'
                                , 'Files/vendor/angular/angular-sanitize.min.js'
                                , 'Files/vendor/general/toastr/toastr.min.js'
                                , 'Files/vendor/ladda/spin.min.js'
                                , 'Files/vendor/ladda/ladda.min.js'
                                , 'Files/vendor/ladda/prism.js'
                                , 'Files/vendor/ladda/spin.min.js'
                                , 'Files/vendor/ladda/laddaDirective.js'
                                , 'Files/vendor/jquery-knob/jquery.knob.js'
                                , 'app/modules/module.widgets/flipClock/jquery.flipcountdown.js'
                                , 'app/modules/module.widgets/timepicker2/clockpicker.js'
                                , 'app/modules/module.widgets/tree/angular.treeview.js'
                                , 'Files/vendor/bootstrap/colorpicker/bootstrap-colorpicker-module.js'

                            ],
                            dest: 'release/js/vendor_js_all.js'
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
                            src: ["app/**/*.1.js"
                                , "app/**/*.2.js"
                                , "app/**/*.3.js"
                                , "app/**/*.4.js"
                                , "app/app.js"

                            ],
                            dest: 'release/js/js_app.js'
                        }




            

        },
        //*****************************************annonate**********************************************************************
        ngAnnotate: {
            options: {
                singleQuotes: true
            },
            app: {
                files: {
                    'release/js/js_app.annonate.js': ['release/js/js_app.js']

                }
            }
        },
        html2js: {
            options: {
                base: '../Website/',
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
                src: ['app/**/*.html'],
                dest: 'release/js/templates.js'
            }
        },
        //**************************************uglify********************************************************************
        uglify:{
                        js_general_apps: {
                            src: 'release/js/general_apps_all.js',
                            dest: 'release/js/general_apps_all.min.js'
                        },
                        js_general_translate: {
                            src: 'release/js/translate_js_all.js',
                            dest: 'release/js/translate_js_all.min.js'
                        },
                        js_app: {
                            src: 'release/js/js_app.annonate.js',
                            dest: 'release/js/js_app.annonate.min.js'
                        },
                       
        },
        //***************************************css min*******************************************************************
        cssmin: {
            css_general_list: { //all systems
                src: 'release/css/css_general_list.css',
                dest: 'release/css/css_general_list.min.css'
            },
            css_template_list: {//all systems
                src: 'release/css/css_template_list.css',
                dest: 'release/css/css_template_list.min.css'
            },
            css_MF: {
                src: 'release/css/mf.css',
                dest: 'release/css/mf.min.css'
            },
            css_CR: {
                src: 'release/css/cyber-rain.css',
                dest: 'release/css/cyber-rain.min.css'
            },
            css_GSI: {
                src: 'release/css/gsi.css',
                dest: 'release/css/gsi.min.css'
            }
        }

    });

    grunt.loadNpmTasks('grunt-html2js');
    grunt.loadNpmTasks('grunt-contrib-concat');
    grunt.loadNpmTasks('grunt-contrib-uglify');
    grunt.loadNpmTasks('grunt-contrib-cssmin');
    grunt.loadNpmTasks('grunt-ng-annotate');
    grunt.loadNpmTasks('grunt-contrib-copy');
    grunt.registerTask('default', ['copy','concat','html2js','ngAnnotate', 'cssmin', 'uglify']);   //,  'html2js','ngAnnotate', 'cssmin', 
};

//For defaule Task       run: grunt          
//For watch              run: grunt watch   // that service will run forever and run the specify tasks for any save according to relevant file . we run grunt watch before working
//For concatenate        run: grunt concat
//For uglify             run: grunt uglify
//For cssmin             run: grunt cssmin
//For build all commands run: grunt build