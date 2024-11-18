/// <reference path="GSI_Programs.html" />

(function (angular) {
    'use strict';
    //////////////// AngularJS //////////////
    angular.module('module.GSI.Device')
        .directive('irrigationProgram', irrigationProgramFactory);



    function irrigationProgramFactory() {
        return {
            restrict: 'EA',

            templateUrl: 'app/modules.devices/GSI.Device/programs/GSI_Programs.html',

            controller: ['$scope', function ($scope) {
               
                var heigthFactor = 0;
                $(function () {
                    $("#slider-range-max").slider({
                        range: "max",
                        min: 0,
                        max: 59,
                        value: 1,
                        slide: function (event, ui) {
                            $("#amount").val(ui.value);
                            $('.programTable tbody tr').css('height', (ui.value * 5)+35);
                            heigthFactor = ui.value;
                            createValvesElements();
                        }
                    });
                    $("#amount").val($("#slider-range-max").slider("value"));
                });
                //*******************************yoman setting**************************************************************
                $scope.scheduling = {
                    state: "Weekly",
                    weekly:{
                        days: [{ num: 0, des: "Sun", state: true }, { num: 1, des: "Mon", state: false }, { num: 2, des: "Tue", state: true }, { num: 3, des: "Wed", state: true }, { num: 4, des: "Thu", state: true }, { num: 5, des: "Fri", state: true }, { num: 6, des: "Sat", state: true }]
                    },
                    cyclic: {
                        date: 1452067381081,
                        daysInterval:2
                    }

                }


                $scope.startTimes = {
                    state: "start",
                    starts: [{time:1452067381081},{time:1452067381081},{time:1452067381081},{time:1452067381081}],
                    intervals: {
                        start:{
                            time:1452067381081,
                            isOff:true
                        },
                        cycles: 5,
                        interval:3600
                    }

                }

                $scope.valves = {
                    currentMethod: 0,
                    list: [
                            { valve: 1, duration: 900, quantity: 2, im: 0, mm: 0 },
                            { valve: 2, duration: 900, quantity: 2, im: 0, mm: 0 },
                            { valve: 3, duration: 900, quantity: 2, im: 0, mm: 0 },
                            { valve: 4, duration: 900, quantity: 2, im: 0, mm: 0 },
                            { valve: 5, duration: 900, quantity: 2, im: 0, mm: 0 },
                            { valve: 6, duration: 900, quantity: 2, im: 0, mm: 0 },
                            { valve: 7, duration: 900, quantity: 2, im: 0, mm: 0 },
                            { valve: 8, duration: 900, quantity: 2, im: 0, mm: 0 },
                            { valve: 9, duration: 900, quantity: 2, im: 0, mm: 0 },
                            { valve: 10, duration: 900, quantity: 2, im: 0, mm: 0 },
                            { valve: -1, duration: 900, quantity: 2, im: 0, mm: 0 },
                            { valve: -1, duration: 900, quantity: 2, im: 0, mm: 0 },
                    ]
                }

                //**************************************yoman************************************************
                $scope.time = ["00:00", "00:30", "01:00", "01:30", "02:00", "02:30", "03:00", "03:30", "04:00", "04:30", "05:00", "05:30", "06:00", "06:30", "07:00", "07:30", "08:00", "08:30", "09:00", "09:30", "10:00", "10:30", "11:00", "11:30", "12:00", "12:30", "13:00", "13:30", "14:00", "14:30", "15:00", "15:30", "16:00", "16:30", "17:00", "17:30", "18:00", "18:30", "19:00", "19:30", "20:00", "20:30", "21:00", "21:30", "22:00", "22:30", "23:00", "23:30", "24:00"];
                $scope.timeMili = [0, 1800, 3600, 5400, 7200, 9000, 10800, 12600, 14400, 16200, 18000, 19800, 21600, 23400, 25200, 27000, 28800, 30600, 32400, 34200, 36000, 37800, 39600, 41400, 43200, 45000, 46800, 48600, 50400, 52200, 54000, 55800, 57600, 59400, 61200, 63000, 64800, 66600, 68400, 70200, 72000, 73800, 75600, 77400, 79200, 81000, 82800, 84600];
                $scope.days=[{ date: "04", day: 0, name: "Sun" }, { date: "05", day: 1, name: "Mon" }, { date: "06", day: 2, name: "Tue" }, { date: "07", day: 3, name: "Wed" }, { date: "08", day: 4, name: "Thu" }, { date: "09", day: 5, name: "Fri" }, { date: "10", day: 6, name: "Sat" }];
                $scope.records = [{ day: 0, program: 'A', start: 1500, valves: [{ name: 's1', duration: 900, time: 1500 }, { name: 's2', duration: 900, time: 2400 }, { name: 's3', duration: 900, time: 3300 }, { name: 's4', duration: 900, time: 4200 }, { name: 's5', duration: 900, time: 5100 }, { name: 's6', duration: 900, time: 6000 }, { name: 's7', duration: 900, time: 6900 }, { name: 's8', duration: 900, time: 7800 }, { name: 's9', duration: 900, time: 8700 }] },
                                  { day: 1, program: 'A', start:19000, valves: [{ name: 's1', duration: 900, time: 19900 }, { name: 's2', duration: 900, time: 21800 }, { name: 's3', duration: 900, time: 22700 }, { name: 's4', duration: 900, time: 23600 }, { name: 's5', duration: 900, time: 24500 }, { name: 's6', duration: 900, time: 25400 }, { name: 's7', duration: 900, time: 26300 }, { name: 's8', duration: 900, time: 27200 }, { name: 's9', duration: 900, time: 28100 }] },
                                  { day: 2, program: 'B', start: 6500, valves: [{ name: 's1', duration: 900, time: 6500 }, { name: 's2', duration: 900, time: 7400 }, { name: 's3', duration: 900, time: 8300 }, { name: 's4', duration: 900, time: 9200 }, { name: 's5', duration: 900, time: 10100 }, { name: 's6', duration: 900, time: 11000 }, { name: 's7', duration: 900, time: 11900 }, { name: 's8', duration: 900, time: 12800 }, { name: 's9', duration: 900, time: 13700 }] },
                                  { day: 3, program: 'B', start: 6500, valves: [{ name: 's1', duration: 900, time: 6500 }, { name: 's2', duration: 900, time: 7400 }, { name: 's3', duration: 900, time: 8300 }, { name: 's4', duration: 900, time: 9200 }, { name: 's5', duration: 900, time: 10100 }, { name: 's6', duration: 900, time: 11000 }, { name: 's7', duration: 900, time: 11900 }, { name: 's8', duration: 900, time: 12800 }, { name: 's9', duration: 900, time: 13700 }] },
                                  { day: 4, program: 'B', start: 6500, valves: [{ name: 's1', duration: 900, time: 6500 }, { name: 's2', duration: 900, time: 7400 }, { name: 's3', duration: 900, time: 8300 }, { name: 's4', duration: 900, time: 9200 }, { name: 's5', duration: 900, time: 10100 }, { name: 's6', duration: 900, time: 11000 }, { name: 's7', duration: 900, time: 11900 }, { name: 's8', duration: 900, time: 12800 }, { name: 's9', duration: 900, time: 13700 }] },
                                  { day: 5, program: 'B', start: 6500, valves: [{ name: 's1', duration: 900, time: 6500 }, { name: 's2', duration: 900, time: 7400 }, { name: 's3', duration: 900, time: 8300 }, { name: 's4', duration: 900, time: 9200 }, { name: 's5', duration: 900, time: 10100 }, { name: 's6', duration: 900, time: 11000 }, { name: 's7', duration: 900, time: 11900 }, { name: 's8', duration: 900, time: 12800 }, { name: 's9', duration: 900, time: 13700 }] },
                                  { day: 6, program: 'B', start: 6500, valves: [{ name: 's1', duration: 900, time: 6500 }, { name: 's2', duration: 900, time: 7400 }, { name: 's3', duration: 900, time: 8300 }, { name: 's4', duration: 900, time: 9200 }, { name: 's5', duration: 900, time: 10100 }, { name: 's6', duration: 900, time: 11000 }, { name: 's7', duration: 900, time: 11900 }, { name: 's8', duration: 900, time: 12800 }, { name: 's9', duration: 900, time: 13700 }] }

                ];

                //******************************************************************************************
                $scope.getColor = function(s) {
                    switch (s) {
                        case 's1': return '#9aa99b';
                            break;
                        case 's2': return '#71a795';
                            break;
                        case 's3': return '#65a7c4';
                            break;
                        case 's4': return '#5680b5';
                            break;
                        case 's5': return '#6c6ca4';
                            break;
                        case 's6': return '#84709b';
                            break;
                        case 's7': return '#847484';
                            break;
                        case 's8': return '#dd8c4f';
                            break;
                        case 's9': return '#c6705e';
                            break;
                        case 's10': return '#aa6d56';
                            break;
                        case 's11': return '#a06d97';
                            break;
                        case 's12': return '#944080';
                            break;
                        case 's13': return '#a62e69';
                            break;
                        case 's14': return '#b79bc1';
                            break;
                        case 's15': return '#b77080';
                            break;
                        case 's16': return '#dddb5b';
                            break;
                        case 's17': return '#c6aa5e';
                            break;
                        case 's18': return '#aaa856';
                            break;
                        case 's19': return '#86acb5';
                            break;
                        case 's20': return '#948180';
                            break;
                        case 's21': return '#a68469';
                            break;
                        case 's22': return '#b7885e';
                            break;
                        case 's23': return '#b7acb7';
                            break;
                        case 's24': return '#bfbd8e';
                            break;

                    }

                }
                //*****************************************************************************************
                function createValvesElements() {

                   


                    var arr = [0, 0, 0, 0, 0, 0, 0]
                    for (var i = 0; i < $scope.records.length; i++) {
                        if (document.getElementById('record' + i)) {
                            $('#record' + i).remove();

                        }



                        var mainDiv = document.createElement("Div");
                        mainDiv.id = 'record' + i;
                        mainDiv.style.position = 'absolute';//***************************************
                        mainDiv.style.border = '1px solid grey';
                        mainDiv.style.padding = '2px';
                        mainDiv.style.borderRadius = '6px';

                        const mainDivWIDTH = 70;
                        mainDiv.style.width = mainDivWIDTH + "px";
                        mainDiv.style.marginLeft = ((mainDivWIDTH + 7) * arr[$scope.records[i].day]) + 'px';
                        arr[$scope.records[i].day]++;
                        var programDiv = document.createElement("Div");
                        programDiv.style.backgroundColor = 'white';
                        programDiv.style.width = '30px';
                        programDiv.style.height = '20px';
                        programDiv.style.float = 'right';
                        programDiv.style.border = '1px solid gray';
                        programDiv.style.paddingLeft = '10px';
                        programDiv.innerHTML = $scope.records[i].program;
                        mainDiv.appendChild(programDiv);

                        var valvesDiv = document.createElement("Div");


                        for (var j = 0; j < $scope.records[i].valves.length; j++) {
                            var rowHeigth = (heigthFactor * 5) + 35;
                            $scope.records[i].valves[j].height = (($scope.records[i].valves[j].duration / 60) / 30) * rowHeigth + 'px';
                            var subDiv = document.createElement("Div");
                            var spanDiv = document.createElement("Span");
                            spanDiv.innerHTML = $scope.records[i].valves[j].name;
                            spanDiv.style.marginLeft = '7px';
                            spanDiv.style.verticalAlign = '-webkit-baseline-middle';
                            spanDiv.style.color = 'white';
                            subDiv.appendChild(spanDiv);

                            subDiv.style.height = $scope.records[i].valves[j].height;
                            subDiv.style.width = mainDivWIDTH-3+'px';
                            var time = convertUnixToTime($scope.records[i].valves[j].time).toLocaleTimeString().replace("/.*(\d{2}:\d{2}:\d{2}).*/", "$1");
                            subDiv.setAttribute("data-toggle", "tooltip");
                            subDiv.setAttribute("title", "Start Time: " + time + " Duration: " + $scope.records[i].valves[j].duration / 60 + " Min");
                            subDiv.style.backgroundColor = $scope.getColor($scope.records[i].valves[j].name);

                            valvesDiv.appendChild(subDiv);
                        }
                        mainDiv.appendChild(valvesDiv);
                        recordLocation(mainDiv, $scope.records[i])

                        for (var j = 0; j < arr.length; j++) {
                            var elem = document.getElementById('PITH' + j).style.minWidth = arr[j] * (mainDivWIDTH + 7) + 'px';

                        }

                    }
                    //  recordLocation(ctx, $scope.records[0])

                }
                //*****************************************************************************************
                function recordLocation(Div, record) {
                    
                    var start = record.start;
                    var index = 0;
                    var value = 0;
                    for (var i = 0; i < $scope.timeMili.length; i++) {
                        if ($scope.timeMili[i] > start) {
                           
                            index = i-1;
                            
                           
                            break;
                        }
                    }
                    var rowHeigth = (heigthFactor * 5) + 35;
                    start = start % 1800;
                    var offsetTop =Math.round(start /1800  * rowHeigth);
                    var fatherDivString = 'PI' + index.toString() + record.day.toString();
                    var fatherDivObject = angular.element('#' + fatherDivString);


                    Div.style.marginTop = offsetTop + 'px';
                    fatherDivObject.append(Div);

                }

                //*****************************************************************************************
                var myVar = setTimeout(function () {

                    //var canvas = document.createElement('canvas');

                    //canvas.id = "CursorLayer";
                    //canvas.width = 100;
                    //canvas.height = 100;
                    //canvas.style.zIndex = 8;
                    //canvas.style.position = "absolute";
                    //canvas.style.background = "black";
                    //canvas.style.border = "1px solid";
                    //var el = document.getElementById('PI03');
                    //el.appendChild(canvas);

                    createValvesElements();
                }, 100);
                //******************************************************************************************
                function stringToUnix(sec) { //only for clock(write) not for date

                    if (sec.indexOf("M") > -1) {
                        var n = sec.indexOf("M");
                        sec = sec.insertAt(n - 1, " ");
                    }
                    var time = new Date("October 13, 2014" + " " + sec);
                    return time.getSeconds() + (60 * time.getMinutes()) + (60 * 60 * time.getHours());
                };
                //******************************************************************************************
                function convertUnixToTime(millisecondsMidnight) {    //only for clock(read) not for date

                    var d = new Date(0);
                    var minutes = millisecondsMidnight / 60;
                    d.setHours(minutes / 60);
                    var minutes = minutes % 60
                    d.setMinutes(minutes);
                    if (minutes % 1 === 0) {
                        d.setSeconds(0);
                    } else {
                        minutes = Math.abs(minutes); // Change to positive
                        var decimal = (minutes - Math.floor(minutes))*60
                        d.setSeconds(decimal);
                    }
                    
                    return d;
                };
                //*********************************************************************************************

            }],
            link: function (scope, element, attrs, ngModel) {



            }




        };

    }
})(angular);

    /*******************************************************************************************************************************************************************************/
