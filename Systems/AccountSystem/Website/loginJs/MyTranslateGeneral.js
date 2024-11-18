//************************************************setLenguageFlags****************************************
function setLenguageFlags(){
    var Flags = [{ lenguage: "en", flagUrl: "../Content/img/en-US.png" },
                 { lenguage: "es", flagUrl: "../Content/img/spain_flag.png" },
                 { lenguage: "fr", flagUrl: "../Content/img/france_flag.png" }
    ];

    $('#enImage').attr('src', Flags[0].flagUrl);
    $('#esImage').attr('src', Flags[1].flagUrl);
    $('#frImage').attr('src', Flags[2].flagUrl);
    return Flags;
}
//************************************************getAllSupportedItems****************************************
function getAllSupportedItems(lan) {
    $.ajax({
        crossDomain: true,
        contentType: "application/json",
        url: '/Content/laguage/' + lan + '.txt',
        headers: { 'Access-Control-Allow-Origin': '*' },
        type: "GET",
        dataType: "json",
        success: function (data) {
            var translateList1 = $('[translate]');
            translateList1.each(function () {
                var value = this.attributes['translate'].nodeValue;
                this.innerHTML = data[value];

            });
            var translateList2 = $('[placeholder]');
            translateList2.each(function () {
                var value = this.attributes['placeholder'].nodeValue;
                this.attributes['placeholder'].nodeValue = data[value];

            });
        }
    });
}
//************************************************************GetCoockie*************************************************************
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
//************************************************************setCookie*********************************
function setCookie(cname, cvalue, exdays) {
    var d = new Date();
    d.setTime(d.getTime() + (exdays * 24 * 60 * 60 * 1000));
    var expires = "expires=" + d.toUTCString();
    document.cookie = cname + "=" + cvalue + ";path=/;" + expires;
}
//****************************************************************************************
function setLanguage(len, url) {
    setCookie("selectedLanguage", len , 30);
    location.reload();
}
$(document).ready(function () {
    var allData;
    if(getCookie("selectedLanguage")){
        selectedLanguage =getCookie("selectedLanguage");
    } else {
        setCookie("selectedLanguage", "en", 30);
        selectedLanguage ='en';
    }
  
    var Flags = setLenguageFlags();
    for (var i = 0; i < Flags.length; i++) {
        if (Flags[i].lenguage == selectedLanguage) {
            $("#LanId").attr('src', Flags[i].flagUrl);
        }
    }
    

    if (selectedLanguage == 'en') {
        $("#LanName").text('en');
         getAllSupportedItems('en');
     
    } if (selectedLanguage == 'es') {
        $("#LanName").text('es');
         getAllSupportedItems('es');
       
    }
    if (selectedLanguage == 'fr') {
        $("#LanName").text('fr');
         getAllSupportedItems('fr');
       
    }

   


});