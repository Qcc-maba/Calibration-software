


function getParameterByName(name) {
    name = name.replace(/[\[]/, "\\\[").replace(/[\]]/, "\\\]");
    var regex = new RegExp("[\\?&]" + name + "=([^&#]*)"), results = regex.exec(location.search);
    return results == null ? "" : decodeURIComponent(results[1]);//.replace(/\+/g, " "));
};
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
function setCookie(cname, cvalue, exdays) {
    var d = new Date();
    d.setTime(d.getTime() + (exdays * 24 * 60 * 60 * 1000));
    var expires = "expires=" + d.toUTCString();
   

    document.cookie = cname + "=" + cvalue + ";path=/;" + expires;
}
function delete_cookie(name) {
    document.cookie = name + '=;path=/; expires=Thu, 01 Jan 1970 00:00:01 GMT;';
}
function httpPOST(relativeUrl, data) {

    var promise = $.ajax({

        type: "POST",
        contentType: "application/json",
        url: relativeUrl,
        data: data,
        dataType: "json"
    });

    return promise;
}
function checkAccessToken() {

    var AccessTokenAccount = getParameterByName('AccessTokenAccount');

    var encodedReturnUrl = getParameterByName('returnUrl');

    if (AccessTokenAccount.length) {

        //Found Access token (Facebook, Google etc..)
        setCookie("AccessTokenAccount", AccessTokenAccount, 7);
        if (encodedReturnUrl.length) {
            var returnUrl = encodedReturnUrl;


            var returnUrl = getParameterByName('returnUrl');
            fixLoadingOn("Login");
            window.location = returnUrl;
            if (returnUrl.indexOf("?") >= 0) {
                fixLoadingOn("Login");
                window.location = returnUrl;

            } else {
                fixLoadingOn("Login");
                window.location = returnUrl;

            }
        } else {
            fixLoadingOn("Login");//pppp
            window.location = MAIN_LINKS.ACCOUNT_APP_LIST.link;

        }


    } else {
        //not found Access Token
        delete_cookie("AccessTokenAccount");

    }
}
function getObject(str) {
    switch (str) {
        case "System_ACCOUNT_ADMIN":
            return ACCOUNT_LOGIN_URI;
            break;
        case "System_MF":
            return MF_ROOT_URI;
            break;
        case "System_XCI_ADMIN":
            return XCI_ADMIN;
            break;
        case "System_GSI_ADMIN":
            return GSI_ADMIN;
            break;
    }
}



//*****Actions we do when the login page is up************************************************************************************************************************************************
//*** if we are in account system and url dont have token delete the current token
if ((getCookie("AccessTokenAccount").length > 0) && (getParameterByName('AccessTokenAccount').length < 1) && (getParameterByName('box') == "login")) {
    delete_cookie("AccessTokenAccount");
}
//******************************************************************Login************************************
var Login = function () {



    var runLoginButtons = function () {

        var el = $('.box-login');
        if (getParameterByName('box').length) {
            switch (getParameterByName('box')) {
                case "register":
                    el = $('.box-register');
                    el.show();
                    break;
                case "app":
                    el = $('.box-app');
                    el.show();
                    var postRequest = $.ajax({

                        type: "GET",
                        beforeSend: function (request) {
                            request.setRequestHeader("Authorization", 'Bearer ' + getCookie('AccessTokenAccount'));
                        },
                        contentType: "application/json",
                        url: ROOT_ADDR.SYSTEM_ACCOUNT_API + "/Account/Systems",
                        data: JSON.stringify(obj),
                        dataType: "json",
                        success: function (data) {
                            data = data.body;

                            if(data.systems.length>1){
                                var appUl = document.getElementById("appUl");
                                var myObject;
                                for (var i = 0; i < data.systems.length; i++) {
                                    myObject = getObject(data.systems[i].systemName)
                                    var li = document.createElement('li');
                                    li.setAttribute("BaseUrl", myObject.BaseUrl);
                                    var img = document.createElement('img');
                                    img.src = myObject.ImageSrc;
                                    img.style.width = "70px";
                                    img.style.height = "70px";
                                    var h3 = document.createElement('h3');
                                    h3.innerHTML = myObject.Title;
                                    var p = document.createElement('p');
                                    p.innerHTML = myObject.SubTitle;
                                    li.appendChild(img);
                                    li.appendChild(h3);
                                    li.appendChild(p);
                                    var goTo = function () {
                                        fixLoadingOn("Login");
                                        window.location = this.attributes[0].nodeValue;
                                    }
                                    li.onclick = goTo;
                                    appUl.appendChild(li);

                             
                                    //  fixLoadingOff();
                            }

                            } else {
                                window.location = MF_ROOT_URI.BaseUrl;
                            }
                        },
                        error: function (data) {
                            //  fixLoadingOff();


                        }
                    });
                    break;
                case "forgot":
                    el = $('.box-forgot');
                    el.show();
                    break;
                case "reset":
                    el = $('.box-reset');
                    el.show();
                    
                    break;
                case "thankYou":
                    el = $('.box-thankYou');
                    el.show();
                    $('.thankYouLoading').show();
                    var fff = getParameterByName('AccessToken');
                    var obj = {
                        requestId: getParameterByName('requestId'),
                        confirmEmailToken: fff,
                        email: getParameterByName('email')
                    };
                    var postRequest = $.ajax({

                        type: "POST",
                        contentType: "application/json",
                        url: ROOT_ADDR.SYSTEM_ACCOUNT_API + "/Login/ConfirmEmail",
                        data: JSON.stringify(obj),
                        dataType: "json",
                        success: function (data) {
                            $('#thankYouSuccessFrame').show();
                            $('.thankYouSuccess').show();
                            $('.thankYouLoading').hide();
                            $('.thankYouError').hide();
                            el = $('.box-thankYou');
                            el.show();
                        },
                        error: function (data) {
                            $('.thankYouError').show();
                            $('.thankYouLoading').hide();
                            $('.thankYouSuccess').hide();
                            $('#thankYouSuccessFrame').hide();

                        }
                    });
                    break;
                default:
                    checkAccessToken();
                    el = $('.box-login');

                    el.show();
                    break;
            }
        } else {

            checkAccessToken();
            var AccessTokenAccount= getParameterByName('AccessTokenAccount');
            if (AccessTokenAccount.length) {
                setCookie("AccessTokenAccount", AccessTokenAccount, 7);
            }
            el = $('.box-login');
            el.show();
        }

    };
    var runSetDefaultValidation = function () {
        $.validator.setDefaults({
            errorElement: "span", // contain the error msg in a small tag
            errorClass: 'help-block',
            errorPlacement: function (error, element) { // render error placement for each input type
                if (element.attr("type") == "radio" || element.attr("type") == "checkbox") { // for chosen elements, need to insert the error after the chosen container
                    error.insertAfter($(element).closest('.form-group').children('div').children().last());
                } else if (element.attr("name") == "card_expiry_mm" || element.attr("name") == "card_expiry_yyyy") {
                    error.appendTo($(element).closest('.form-group').children('div'));
                } else {
                    error.insertAfter(element);
                    // for other inputs, just perform default behavior
                }
            },
            ignore: ':hidden',
            highlight: function (element) {
                $(element).closest('.help-block').removeClass('valid');
                // display OK icon
                $(element).closest('.form-group').removeClass('has-success').addClass('has-error').find('.symbol').removeClass('ok').addClass('required');
                // add the Bootstrap error class to the control group
            },
            unhighlight: function (element) { // revert the change done by hightlight
                $(element).closest('.form-group').removeClass('has-error');
                // set error class to the control group
            },
            success: function (label, element) {
                label.addClass('help-block valid');
                // mark the current input as valid and display OK icon
                $(element).closest('.form-group').removeClass('has-error');
            },
            highlight: function (element) {
                $(element).closest('.help-block').removeClass('valid');
                // display OK icon
                $(element).closest('.form-group').addClass('has-error');
                // add the Bootstrap error class to the control group
            },
            unhighlight: function (element) { // revert the change done by hightlight
                $(element).closest('.form-group').removeClass('has-error');
                // set error class to the control group
            }
        });
    };
    var runLoginValidator = function () {
        var form = $('.form-login');
        var errorHandler = $('.errorHandler', form);
        form.validate({
            rules: {
                emailLogin: {
                    required: true
                },
                passwordLogin: {
                    minlength: 6,
                    required: true
                }
            },
            submitHandler: function (form) {
                if ($('#errLoginUl').length) { //remove
                    $('#errLoginUl').remove();
                }
                errorHandler.hide();
                var data = {
                    'email': $('#emailLogin').val(),
                    'password': $('#passwordLogin').val()
                }
                var laddaButton = $('#submitLogin')[0];
                var l = Ladda.create(laddaButton);
                l.start();

                httpPOST(ROOT_ADDR.SYSTEM_ACCOUNT_API + "/Login/LocalLogin", JSON.stringify(data))
                    .done(function (data) {
                        //save access token
                        data = data.body;
                        setCookie("AccessTokenAccount", data.accountToken, 7);
                      
                        var returnUrl = getParameterByName('returnUrl');
                        if (returnUrl.length) {
                            fixLoadingOn("Login");
                            window.location = returnUrl;
                        } else {
                            fixLoadingOn("Login");
                            window.location = MAIN_LINKS.ACCOUNT_APP_LIST.link;
                        }
                        
                        l.stop();
                    })
                    .fail(function (data) {


                        var errList = $('#errLogin');
                        var ul = $('<ul/>').attr("id", "errLoginUl").appendTo(errList);
                        $.each(data.responseJSON.messages, function (i) {
                            var li = $('<li/>')
                                .addClass('red')
                                .text(data.responseJSON.messages[i].message)
                                .appendTo(ul);

                        });

                        l.stop();
                    });
               
            },
            invalidHandler: function (event, validator) { //display error alert on form submit
                errorHandler.show();
            }
        });
    };
    var runResetValidator = function () {
        var form = $('.form-reset');
        var errorHandler = $('.errorHandler', form);
        form.validate({
            rules: {

                NewPassword: {
                    required: true,
                    minlength: 6,
                    maxlength: 10,

                },
                Confirmation: {
                    equalTo: "#NewPassword",
                    minlength: 6,
                    maxlength: 10
                }
            },
            submitHandler: function (form) {
                if ($('#errResetUl').length) { //remove
                    $('#errResetUl').remove();
                }
                errorHandler.hide();
                var data = {
                    'resetPasswordToken': getParameterByName('ResetToken'),
                    'email': getParameterByName('email'),
                    'newPassword': $('#NewPassword').val(),
                    'confirmPassword': $('#Confirmation').val()
                }
                var laddaButton = $('#submitReset')[0];
                var l = Ladda.create(laddaButton);
                l.start();

                var postRequest = $.ajax({

                    type: "POST",
                    contentType: "application/json",
                    url: ROOT_ADDR.SYSTEM_ACCOUNT_API + "/Account/ResetPassword",
                    data: JSON.stringify(data),
                    dataType: "json",
                    success: function (data) {
                        $('#submitReset').hide();
                        $('#resetMsg').show();
                        l.stop();
                    },
                    error: function (data) {
                        $('#submitReset').hide();
                        $('#resetMsg').show();
                        l.stop();
                        //var errList = $('#errReset');
                        //var ul = $('<ul/>').attr("id", "errResetUl").appendTo(errList);
                        //$.each(data.responseJSON.messages, function (i) {
                        //    var li = $('<li/>')
                        //        .addClass('red')
                        //        .text(data.responseJSON.messages[i].message)
                        //        .appendTo(ul);

                        //});
                    }

                });
            },
            invalidHandler: function (event, validator) { //display error alert on form submit
                errorHandler.show();
            }
        });
    };
    var runForgotValidator = function () {
        var form2 = $('.form-forgot');
        var errorHandler2 = $('.errorHandler', form2);
        form2.validate({
            rules: {
                email: {
                    required: true
                }
            },
            submitHandler: function (form) {
                if ($('#errForgetUl').length) { //remove
                    $('#errForgetUl').remove();
                }
                errorHandler2.hide();
                var data = {
                    'email': $('#emailForget').val(),
                    'resetPasswordPageUrl': window.location.href.substr(0, window.location.href.indexOf('=')) + "=reset"
                }
                var laddaButton = $('#submitForget')[0];
                var l = Ladda.create(laddaButton);
                l.start();

                var postRequest = $.ajax({

                    type: "POST",
                    contentType: "application/json",
                    url:  ROOT_ADDR.SYSTEM_ACCOUNT_API + "/Account/ForgotPassword",
                    data: JSON.stringify(data),
                    dataType: "json",
                    success: function (data) {
                        $('#submitForget').hide();
                        $('#forgotPassMsg').show();
                        l.stop();
                    },
                    error: function (data) {
                        $('#submitForget').hide();
                        $('#forgotPassMsg').show();
                        l.stop();
                        //var errList = $('#errForget');
                        //var ul = $('<ul/>').attr("id", "errForgetUl").appendTo(errList);
                        //$.each(data.responseJSON.messages, function (i) {
                        //    var li = $('<li/>')
                        //        .addClass('red')
                        //        .text(data.responseJSON.messages[i].message)
                        //        .appendTo(ul);

                        //});
                    }

                });
            },
            invalidHandler: function (event, validator) { //display error alert on form submit
                errorHandler2.show();
            }
        });
    };
    var runRegisterValidator = function () {
        var form3 = $('.form-register');
        var errorHandler3 = $('.errorHandler', form3);
        form3.validate({
            rules: {
                firstName: {
                    minlength: 2,
                    required: true
                },
                LastName: {
                    minlength: 2,
                    required: true
                },
                address: {
                    minlength: 2,
                    required: true
                },
                phone: {
                    required: true,
                    digits: true
                },

                RegEmail: {
                    required: true
                },
                RegPassword: {
                    minlength: 6,
                    required: true
                },
                confirmPassword: {
                    required: true,
                    minlength: 6,
                    equalTo: "#RegPassword"
                }
            },
            submitHandler: function (form) {

                if ($('#errUl').length) { //remove
                    $('#errUl').remove();
                }
                errorHandler3.hide();
                var data = {
                    'firstName': $('#firstName').val(),
                    'lastName': $('#lastName').val(),
                    'address': $('#address').val(),
                    'email': $('#RegEmail').val(),
                    'phone': $('#phone').val(),
                    'password': $('#RegPassword').val(),
                    'confirmPassword': $('#confirmPassword').val(),
                    'confirmEmailPageUrl': window.location.href.substr(0, window.location.href.indexOf('=register')) + "=thankYou"
                }
                var laddaButton = $('#submitRegister')[0];
                var l = Ladda.create(laddaButton);
                l.start();

                var postRequest = $.ajax({

                    type: "POST",
                    contentType: "application/json",
                    url: ROOT_ADDR.SYSTEM_ACCOUNT_API + "/Login/Register",
                    data: JSON.stringify(data),
                    dataType: "json",
                    success: function (data) {
                        $('#submitRegister').hide();
                        $('#emailConfirmDiv').show();
                        l.stop();
                    },
                    error: function (data) {
                        //$.each($('#RegisterErr li'), function (i) { i.hide(); });

                        l.stop();
              
                     

                        $('#RegisterErr').show();
                        $.each(data.responseJSON.messages, function (i) {

                            switch (data.responseJSON.messages[i].code) {
                                case 4:
                                    $('#Register_Message_4').show();
                                    break;
                                default:
                                    $('#Register_Message_6').show();
                                    break;
                            }
                        });
                    }

                });


            },
            invalidHandler: function (event, validator) { //display error alert on form submit
                errorHandler3.show();
            }
        });
    };



    $("#google").click(function () {
        var laddaButton = $('#google')[0];
        var l = Ladda.create(laddaButton);
        l.start();
        //save cocki
        var encodedCurrentUri = encodeURIComponent(window.location.href);
        window.location = ROOT_ADDR.SYSTEM_ACCOUNT_API + "/Login/ExternalLogin?provider=Google&returnUrl=" + encodedCurrentUri;

    });

    $("#facebook").click(function () {
        var laddaButton = $('#facebook')[0];
        var l = Ladda.create(laddaButton);
        l.start();

        var encodedCurrentUri = encodeURIComponent(window.location.href);
        window.location = ROOT_ADDR.SYSTEM_ACCOUNT_API + "/Login/ExternalLogin?provider=Facebook&returnUrl=" + encodedCurrentUri;

    });

    return {
        //main function to initiate template pages
        init: function () {
            runLoginButtons();
            runSetDefaultValidation();
            runLoginValidator();
            runResetValidator();
            runForgotValidator();
            runRegisterValidator();
        }
    };
}();




$(".appUl li").hover(function () {
    $(this).find(".arrow_img").show()
},
        function () {
            $(this).find(".arrow_img").hide()
});

