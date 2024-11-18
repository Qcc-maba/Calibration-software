
(function (angular) {
    'use strict';

    //////////////// AngularJS //////////////
    angular.module('module.translate')
        .provider('translate', translate);


    //////////////// JavaScript //////////////

    function translate() {
        var _Settings = {
            GMT_Offset: '',
        };
        function _UpdateGMT_Offset(offset) {
            _Settings.GMT_Offset = offset;
        };
        var date = {
            'startUnix': '',
            'endUnix': ''
        };
        function changeLanguage  (str) {
            //use parameter needs to be part of a known locale Eg: en-UK, en, etc
            $translate.use(str);
        };
        function convertUnixToTime(millisecondsMidnight) {    //only for clock(read) not for date
            
            var d = new Date(0);
            var minutes = millisecondsMidnight / 60;
            d.setHours(minutes / 60);
            d.setMinutes(minutes % 60);
            return d;
        };
        function secsToMinutes(sec) {
            return sec/60;
        };
        function minutesToSecs(min) {
            return min * 60;
        };
        function stringToUnix(sec) { //only for clock(write) not for date
            
            if (sec.indexOf("M") > -1) {
                var n = sec.indexOf("M");
                sec=sec.insertAt(n-1, " ");
            }
            var time = new Date("October 13, 2014" + " " + sec);
            return time.getSeconds() + (60 * time.getMinutes()) + (60 * 60 * time.getHours());
        };


        function fullDateStringToUnixServer(date, timeStr) {

            if (timeStr.indexOf("M") > -1) {
                var n = timeStr.indexOf("M");
                timeStr = timeStr.insertAt(n - 1, " ");
            }
            var localTime = new Date(date + " " + timeStr);
            var GmtAbs = localTime.getTimezoneOffset() * 60 * 1000;
        
            return localTime.getTime() - GmtAbs;
        }
        function FixUnixGmtFromServer(UnixMili) {

            var d = new Date();
            var GmtAbs = d.getTimezoneOffset() * 60 * 1000;

            return UnixMili - GmtAbs;
        }

       

        function clockType(locale) {
            if (locale.DATETIME_FORMATS.shortTime.indexOf("a") != -1) {
                return "AMPM";
            }
            return "ordinary";
        }
      
        String.prototype.insertAt = function (index, string) {
            return this.substr(0, index) + string + this.substr(index);
        }
       
        //***********************getLastYear(Outer)****************
        function getLastYear() {
           
            var localTime = new Date();
            var GmtAbs = localTime.getTimezoneOffset() * 60 * 1000;
            var lastYear = localTime.setFullYear(localTime.getFullYear() - 1)
            date.endUnix = localTime.getTime() - GmtAbs;
            date.startUnix = lastYear - GmtAbs;
            return date;
        }
        //***********************getLastMonth(Outer)****************
        function getLastMonth() {
            
            var localTime = new Date();
            var GmtAbs = localTime.getTimezoneOffset() * 60 * 1000;
            var lastMonth = localTime.setMonth(localTime.getMonth() - 1)
            date.endUnix = localTime.getTime() - GmtAbs;
            date.startUnix = lastMonth - GmtAbs;
            return date;
            //***********************getLastWeek(Outer)****************   
        }
        function getLastWeek() {
            
            var localTime = new Date();
            var GmtAbs = localTime.getTimezoneOffset() * 60 * 1000;
            var lastWeek = new Date(localTime.getFullYear(), localTime.getMonth(), localTime.getDate() - 7);
            date.endUnix = localTime.getTime() - GmtAbs;
            date.startUnix = lastWeek- GmtAbs;
            return date;
        }
     
        return {
            $get: function () {


                //interface
                return {
                    UpdateGMT_Offset: _UpdateGMT_Offset,
                    convertUnixToTime: convertUnixToTime,
                    secsToMinutes: secsToMinutes,
                    fullDateStringToUnixServer:fullDateStringToUnixServer,
                    minutesToSecs:minutesToSecs,
                    stringToUnix: stringToUnix,
                    clockType: clockType,
                
                    getLastYear: getLastYear,
                    getLastMonth: getLastMonth,
                    getLastWeek: getLastWeek,
                    FixUnixGmtFromServer: FixUnixGmtFromServer
                    
                    
    
                  

                };
            }
        }
    }
})(angular);


//translate methods:

//{{myDate | date:'fullDate'}}
//{{money | currency}}
//<p>ffff</p>
//<p translate="varibleInside" translate-values="{count:3}"></p>
//<p>{{"varibleInside" | translate:{ count :6 } }}</p>
//$scope.text = $translate('varibleInside' , { count:3 });
// <p>{{"varibleInside" | translate:{ count :6 , sum:9} }}</p>
//in en file "varibleInside":"you have {{count}} new messages and also {{sum}} miss calls",


