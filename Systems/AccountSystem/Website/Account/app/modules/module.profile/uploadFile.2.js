angular.module('ngSimpleUpload', [])
    .directive('ngSimpleUpload', [function () {
        return {
            scope: {
                webApiUrl: '@',
                callbackFn: '=',
                callbackAn: '=',
                callbackProgress: '=',
                buttonId: '@'
            },
            link: function (scope, element, attrs) {
                function getCookie(cname) {
                    var name = cname + "=";
                    var ca = document.cookie.split(';');
                    for (var i = 0; i < ca.length; i++) {
                        var c = ca[i];
                        while (c.charAt(0) == ' ') c = c.substring(1);
                        if (c.indexOf(name) == 0) return c.substring(name.length, c.length);
                    }
                    return "";
                }
                // if button id value exists
                if (scope.buttonId) {
                    $('#' + scope.buttonId).on('click', function () {
                        
                        // retrieves files from file input
                        var files = element[0].files;
                        // will not fire until file(s) are selected
                        if (files.length == 0) {
                            console.log('No files detected.');
                            return false;
                        }

                        Upload(files);
                    });
                }
                else {
                    // original code, trigger upload on change
                    element.on('change', function (evt) {

                   
                        scope.callbackAn(true);
                      
                   
                        
                        var files = evt.__files_ || (evt.target && evt.target.files);

                        Upload(files);
                        
                        // removes file(s) from input
                        $(this).val('');
                    });
                }





                //************************************

                function progress(e) {

                    if (e.lengthComputable) {
                        var max = e.total;
                        var current = e.loaded;

                        var Percentage = (current * 100) / max;
                        Percentage = parseInt(Percentage);
                        console.log(Percentage);


                        if (Percentage <= 99) {
                           scope.callbackProgress(Percentage);
                        }
                    }
                }
                //**

                function Upload(files) {
                    var fd = new FormData();
                    angular.forEach(files, function (v, k) {
                        fd.append('file', files[k]);
                    });

                    return $.ajax({
                        type: 'POST',
                        url: scope.webApiUrl,
                        headers: { 'Authorization': 'Bearer ' + getCookie('AccessTokenAccount') },
                        data: fd,
                        xhr: function () {
                            var myXhr = $.ajaxSettings.xhr();
                            if (myXhr.upload) {
                                myXhr.upload.addEventListener('progress', progress, false);
                            }
                            return myXhr;
                        },
                        async: true,
                        cache: false,
                        contentType: false,
                        processData: false
                    }).done(function (d) {
                        // callback function in the controller
                        scope.callbackFn(d);
                    }).fail(function (x) {
                        console.log(x);
                    });

                   
                }
            }
        }
    }]);