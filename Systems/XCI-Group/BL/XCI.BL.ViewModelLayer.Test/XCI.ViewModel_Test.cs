using System;
using System.Text;
using System.Collections.Generic;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Zone;
using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Repositories.Admin;
using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device;
using Maba.Connectors.ElasticsearchLibrary;
using System.Linq;
using Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device;
using static Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Schedule.BaseDeviceScheduleView;
using Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Schedule;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Test
{
    /// <summary>
    /// Summary description for UnitTest1
    /// </summary>
    [TestClass]
    public class XCI_BL_ViewModel_Test
    {
        private IAdminRepository Repository = null;
        private XCIGroup.BL.ViewModelLayer.Settings.ViewModelLayerSettings _Settings = null;
        private const string SN_FORMAT = "{0}";

        public XCI_BL_ViewModel_Test()
        {
            Repository = new TSQLAdminRepository();
            _Settings = new XCIGroup.BL.ViewModelLayer.Settings.ViewModelLayerSettings();

            _Settings.AdminRepositoryFunc = () =>
            {
                return new DAL.DataAccessLayer.Repositories.Admin.TSQLAdminRepository();
            };

            _Settings.AgricultureRepositoryFunc = () =>
            {
                return new Maba.Connectors.WeatherServices.PETProcessing.AgricultureData.ESAgricultureRepository(new ElasticSettings());
            };
        }

        private DeviceBase CreateDevice(string GUI_ID = null)
        {
            if (string.IsNullOrEmpty(GUI_ID))
            {
                GUI_ID = Guid.NewGuid().ToString();
            }
            var sn = String.Format(SN_FORMAT, GUI_ID, GUI_ID);
            var result = Repository.AddDevice(sn, 1);
            Assert.IsTrue(result != null && result != -1);
            var devcie = Repository.GetDevice(sn);
            Assert.IsTrue(devcie != null && devcie.DeviceID == result.Value);
            return devcie;
        }

        [TestMethod]
        public void TestScheduleAdvisor_New()
        {
            //1.

            var ZoneNum = 1;
            var conter = 0;
            #region Save IrrigationSchedule and Settings

            while (conter < 3)
            {
                int[] StartTimes = null;
                int[] AllowTimes = null;
                var device = CreateDevice();
                if (conter == 0 || conter == 1)
                {                                                          ////    -          +            -          +
                    AllowTimes = new int[] { 0, 21600, 43200, 64800 };   ////00:00->6:00 ,6:00->12:00 ,12:00-18:00,18:00-23:59

                    //// -      +       -       +
                    StartTimes = new int[] { 14400, 36000, 50400, 68400 }; ////4:00 , 10:00 , 14:00 , 19:00
                }

                if (conter == 2)
                {                                          ////    -          +          
                    AllowTimes = new int[] { 0, 18000 };   ////00:00->5:00 ,5:00-23:59

                    //// -      +       -       +
                    StartTimes = new int[] { 14400, 86330 }; ////4:00 , 23:58
                }



                List<IrrigationScheduleItem> items = new List<IrrigationScheduleItem>();

                for (int j = 0; j < 7; j++)
                {
                    for (int z = 0; z < 4; z++)
                    {
                        for (int x = 0; x < StartTimes.Length; x++)
                        {
                            items.Add(new IrrigationScheduleItem() { DayNum = j, StartTime = StartTimes[x], Time = 20, ZoneNum = z });
                        }
                    }
                }

                Assert.IsTrue(Repository.ScheduleType_Update(device.SN, 1));
                Assert.IsTrue(Repository.IrrigationSchedule_Items_Update(device.SN, items, 1));

                var ZoneIrrigationSuggestion = new DAL.DataAccessLayer.Models.Zone.ZoneIrrigationSuggestion() { Number = ZoneNum, Suggestion_TotalWeeklyDays = 4, Suggestion_TotalWeeklyMinutes = 120 };
                Assert.IsTrue(Repository.IrrigationSuggestion_Update(device.SN, ZoneIrrigationSuggestion));

                DaySettings day = null;
                for (int i = 0; i < 7; i++)
                {
                    day = new DaySettings() { DayIndex = (byte)i, MaxDailyCycles = i, MaxDailyIrrigrationSeconds = i };
                    var times = new List<TimeValueItem>();
                    if (i % 2 == 0 || conter == 1) //set in counter = 1 to all day the setting days.
                    {
                        for (int j = 0; j < AllowTimes.Length; j++)
                        {
                            times.Add(new TimeValueItem { Time = AllowTimes[j], Allowed = (j % 2 != 0) });
                        }

                        Assert.IsTrue(Repository.DaySettings_Update(device.SN, day, times));
                    }
                    else
                    {

                        for (int j = 0; j < AllowTimes.Length; j++)
                        {
                            times.Add(new TimeValueItem { Time = AllowTimes[j], Allowed = true });
                        }
                    }

                    Assert.IsTrue(Repository.DaySettings_Update(device.SN, day, times));
                }

                #endregion
                ZoneModelManager ZoneManager = new ZoneModelManager(_Settings);
                ZoneManager.AcceptSuggestion(device.SN, ZoneNum);
                var zoneIrrList = Repository.IrrigationSchedule_GetByZone(device.SN, ZoneNum, 1);
                var acc = Repository.ZoneIrrigationAccumulate_Get(device.SN, ZoneNum);
                if (conter == 0)
                {
                    Assert.IsTrue(acc.Current_TotalWeeklyMinutes == zoneIrrList.ScheduleItems.Sum(t => t.Time) / 60);
                    Assert.IsTrue(acc.Current_WateringDays == zoneIrrList.ScheduleItems.Select(t => t.DayNum).Distinct().ToArray().Length);
                    Assert.IsTrue(zoneIrrList.ScheduleItems.Count == StartTimes.Length);
                    Assert.IsTrue(zoneIrrList.ScheduleItems.FirstOrDefault(d => d.DayNum == 1 && d.StartTime == StartTimes[0]) != null);
                    Assert.IsTrue(zoneIrrList.ScheduleItems.FirstOrDefault(d => d.DayNum == 3 && d.StartTime == StartTimes[0]) != null);
                    Assert.IsTrue(zoneIrrList.ScheduleItems.FirstOrDefault(d => d.DayNum == 5 && d.StartTime == StartTimes[0]) != null);
                    Assert.IsTrue(zoneIrrList.ScheduleItems.FirstOrDefault(d => d.DayNum == 0 && d.StartTime == StartTimes[1]) != null);

                }

                if (conter == 1)
                {
                    Assert.IsTrue(zoneIrrList.ScheduleItems.Count == StartTimes.Length);
                    Assert.IsTrue(zoneIrrList.ScheduleItems.FirstOrDefault(d => d.DayNum == 0 && d.StartTime == StartTimes[1]) != null);
                    Assert.IsTrue(zoneIrrList.ScheduleItems.FirstOrDefault(d => d.DayNum == 2 && d.StartTime == StartTimes[1]) != null);
                    Assert.IsTrue(zoneIrrList.ScheduleItems.FirstOrDefault(d => d.DayNum == 4 && d.StartTime == StartTimes[1]) != null);
                    Assert.IsTrue(zoneIrrList.ScheduleItems.FirstOrDefault(d => d.DayNum == 6 && d.StartTime == StartTimes[1]) != null);

                }


                if (conter == 2)
                {
                    //Assert.IsTrue(zoneIrrList.ScheduleItems.Count == StartTimes.Length);
                    //Assert.IsTrue(zoneIrrList.ScheduleItems.FirstOrDefault(d => d.DayNum == 1 && d.StartTime == StartTimes[1]) != null);
                    //Assert.IsTrue(zoneIrrList.ScheduleItems.FirstOrDefault(d => d.DayNum == 3 && d.StartTime == StartTimes[1]) != null);
                    //Assert.IsTrue(zoneIrrList.ScheduleItems.FirstOrDefault(d => d.DayNum == 5 && d.StartTime == StartTimes[1]) != null);
                    //Assert.IsTrue(zoneIrrList.ScheduleItems.FirstOrDefault(d => d.DayNum == 0 && d.StartTime == 21600) != null);

                }

                conter++;
            }
        }


        [TestMethod]
        public void TestScheduleAdvisor()
        {
            var SN = "0000000000000001";
            var ZoneNum = 1;


            ZoneModelManager ZoneManager = new ZoneModelManager(_Settings);

            ZoneManager.GetScheduleAdvisor(SN, ZoneNum);

            ZoneManager.AcceptSuggestion(SN, ZoneNum);
            ZoneManager.Zone_UpdateSoakSettings(SN, ZoneNum, 5, 8);

        }

        [TestMethod]
        public void TestScheduleItems_odd()
        {
            var device = CreateDevice();
            int[] StartTime = new int[] { 28800, 43200, 64800 }; //8:00,12:00,18:00
            int zoneCount = 4;

            #region add items
            List<IrrigationScheduleItem> items = new List<IrrigationScheduleItem>();
            var counter = 10;
            foreach (var item in StartTime)
            {
                for (int i = 0; i < zoneCount; i++)
                {
                    items.Add(new IrrigationScheduleItem() { Quantity = i * 2 + counter, Time = i * 3 + counter, StartTime = item, ZoneNum = i });
                }
                counter = counter + 20;
            }

            Assert.IsTrue(Repository.ScheduleType_Update(device.SN, (byte)ScheduleTypes.Odd));
            Assert.IsTrue(Repository.IrrigationSchedule_Items_Update(device.SN, items, (byte)ScheduleTypes.Odd));
            #endregion

            DeviceModelManager d = new DeviceModelManager(_Settings);
            DailyScheduleView dailyView = d.GetIrrigationSchedule(device.SN, null) as DailyScheduleView;

            Assert.IsTrue(dailyView.StartTimes.Length == StartTime.Length);

            //check if all time is set
            foreach (var item in StartTime)
            {
                var time = dailyView.StartTimes.FirstOrDefault(s => s.Time == item);
                Assert.IsTrue(time != null);
            }

            foreach (var Zoneitem in dailyView.Zones)
            {
                Assert.IsTrue(Zoneitem.Starts.Count == StartTime.Length);
                var startIndex = 0;

                foreach (var item in StartTime)
                {
                    //get old item.
                    var db_item = items.FirstOrDefault(s => s.StartTime == item && s.ZoneNum == Zoneitem.ZoneNumber);
                    Assert.IsTrue(Zoneitem.Starts[startIndex].Duration == db_item.Time);
                    Assert.IsTrue(Zoneitem.Starts[startIndex].Quantity == db_item.Quantity);
                    startIndex++;
                }
            }

        }

        [TestMethod]
        public void TestScheduleItems_Weekly_ByDay()
        {
            var device = CreateDevice();
            int[] StartTime = new int[] { 28800, 43200, 64800 }; //8:00,12:00,18:00
            int zoneCount = 4;

            #region add items
            List<IrrigationScheduleItem> items = new List<IrrigationScheduleItem>();
            var counter = 10;

            for (int x = 0; x < 7; x++)
            {
                foreach (var item in StartTime)
                {
                    for (int i = 0; i < zoneCount; i++)
                    {
                        items.Add(new IrrigationScheduleItem() { Quantity = i * 2 + counter, Time = i * 3 + counter, StartTime = item, ZoneNum = i, DayNum = x });
                    }
                    counter = counter + 20;
                }
            }


            Assert.IsTrue(Repository.IrrigationSchedule_Items_Update(device.SN, items, (byte)ScheduleTypes.Weekly));
            #endregion

            DeviceModelManager d = new DeviceModelManager(_Settings);
            DailyScheduleView dailyView = null;
            for (int x = 0; x < 7; x++)
            {
                dailyView = d.GetDevice_WeeklySchedule_ByDay(device.SN, x) as DailyScheduleView;
                Assert.IsTrue(dailyView.StartTimes.Length == StartTime.Length);
                //check if all time is set
                foreach (var item in StartTime)
                {
                    var time = dailyView.StartTimes.FirstOrDefault(s => s.Time == item);
                    Assert.IsTrue(time != null);
                }

                foreach (var Zoneitem in dailyView.Zones)
                {
                    Assert.IsTrue(Zoneitem.Starts.Count == StartTime.Length);
                    var startIndex = 0;

                    foreach (var item in StartTime)
                    {
                        //get old item.
                        var db_item = items.FirstOrDefault(s => s.StartTime == item && s.ZoneNum == Zoneitem.ZoneNumber && x == s.DayNum);
                        Assert.IsTrue(Zoneitem.Starts[startIndex].Duration == db_item.Time);
                        Assert.IsTrue(Zoneitem.Starts[startIndex].Quantity == db_item.Quantity);
                        startIndex++;
                    }
                }
            }

        }

        [TestMethod]
        public void TestScheduleItems_Weekly_By_SN()
        {
            var SN = "0a00-0000-0000-0002";// "0000000000000001";
            DeviceModelManager d = new DeviceModelManager(_Settings);
            Assert.IsTrue(Repository.ScheduleType_Update(SN, (byte)ScheduleTypes.Weekly));

            var items_DB = Repository.IrrigationSchedule_Get_OverStartTime(SN, null);

            var IrrigationSchedule = (WeeklyScheduleView)d.GetIrrigationSchedule(SN, null);

            //test days

            for (int x = 0; x < 7; x++)
            {
                var day = IrrigationSchedule.TitleDays[x];
                Assert.IsTrue(day.FirstStartTime == items_DB.ScheduleItems.Where(f => f.DayNum == x).Min(s => s.StartTime));
                Assert.IsTrue(day.NumOfStartTime == items_DB.ScheduleItems.Where(f => f.DayNum == x).Select(s => s.StartTime).Distinct().Count());
            }

            foreach (var item in IrrigationSchedule.Zones)
            {
                for (int i = 0; i < item.Days.Length; i++)
                {
                    var day_item = item.Days[i];
                    Assert.IsTrue(items_DB.ScheduleItems.Where(s => s.DayNum == i && s.ZoneNum == item.ZoneNumber).Sum(x => x.Quantity) == day_item.Quantity);
                    Assert.IsTrue(items_DB.ScheduleItems.Where(s => s.DayNum == i && s.ZoneNum == item.ZoneNumber).Sum(x => x.Time) == day_item.Duration);
                }
            }

        }


        [TestMethod]
        public void TestScheduleItems_Weekly()
        {
            var device = CreateDevice();
            DeviceModelManager d = new DeviceModelManager(_Settings);
            int[] StartTime = new int[] { 28800, 43200, 64800 }; //8:00,12:00,18:00
            int zoneCount = 4;

            #region add items
            List<IrrigationScheduleItem> items = new List<IrrigationScheduleItem>();
            var counter = 10;

            for (int x = 0; x < 7; x++)
            {
                if (x % 2 == 0)
                {
                    foreach (var item in StartTime)
                    {

                        for (int i = 0; i < zoneCount; i++)
                        {
                            items.Add(new IrrigationScheduleItem() { Quantity = i * 2 + counter, Time = i * 3 + counter, StartTime = item, ZoneNum = i, DayNum = x });
                        }
                    }

                    counter = counter + 20;
                }


                else
                {
                    //in odd day only one startTime
                    items.Add(new IrrigationScheduleItem() { Quantity = counter, Time = counter, StartTime = StartTime[2], ZoneNum = 1, DayNum = x });
                }
            }

            Assert.IsTrue(Repository.ScheduleType_Update(device.SN, (byte)ScheduleTypes.Weekly));
            Assert.IsTrue(Repository.IrrigationSchedule_Items_Update(device.SN, items, (byte)ScheduleTypes.Weekly));

            var IrrigationSchedule = (WeeklyScheduleView)d.GetIrrigationSchedule(device.SN, null);

            //test days

            for (int x = 0; x < 7; x++)
            {
                var day = IrrigationSchedule.TitleDays[x];
                if (x % 2 == 0)
                {
                    Assert.IsTrue(day.FirstStartTime == StartTime[0]);
                    Assert.IsTrue(day.NumOfStartTime == 3);
                }
                else
                {
                    Assert.IsTrue(day.FirstStartTime == StartTime[2]);
                    Assert.IsTrue(day.NumOfStartTime == 1);
                }
            }

            foreach (var item in IrrigationSchedule.Zones)
            {
                for (int i = 0; i < item.Days.Length; i++)
                {
                    var day_item = item.Days[i];
                    Assert.IsTrue(items.Where(s => s.DayNum == i && s.ZoneNum == item.ZoneNumber).Sum(x => x.Quantity) == day_item.Quantity);
                    Assert.IsTrue(items.Where(s => s.DayNum == i && s.ZoneNum == item.ZoneNumber).Sum(x => x.Time) == day_item.Duration);
                }
            }


            #endregion
        }
    }
}
