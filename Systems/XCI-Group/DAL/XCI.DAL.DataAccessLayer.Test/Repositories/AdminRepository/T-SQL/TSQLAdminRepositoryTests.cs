using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Repositories.Admin;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Repositories.Admin.Tests
{
    [TestClass()]
    public class XCI_DAL_DataAccessLayer_TSQLAdminRepositoryTests
    {
        private IAdminRepository Repository = null;
        private const string SN_FORMAT = "{0}8888888888{1}";

        public XCI_DAL_DataAccessLayer_TSQLAdminRepositoryTests()
        {
            Repository = new TSQLAdminRepository();
        }

        #region  private function

        private Models.Device.DeviceBase CreateDevice(string GUI_ID = null)
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


        private Models.Zone.ZoneList[] GetDeviceZones(out string SN)
        {
            var device = CreateDevice();
            var zoneList = Repository.GetDeviceZones(device.SN);
            Assert.IsTrue(zoneList != null && zoneList.Length > 0);
            SN = device.SN;
            return zoneList;
        }

        private bool ComperDate(DateTime Date1, DateTime Date2)
        {
            if (Date1.Year == Date2.Year &&
                Date1.Month == Date2.Month &&
                Date1.Day == Date2.Day &&
                Date1.Hour == Date2.Hour &&
                Date1.Minute == Date2.Minute &&
                Date1.Second == Date2.Second)
            {
                return true;
            }

            return false;
        }

        #endregion


        #region Settings

        [TestMethod()]
        public void SettingsTest()
        {
            var device = CreateDevice();
            Models.Device.DeviceSettings setting = new Models.Device.DeviceSettings();
            var count = 0;
            while (count < 2)///one for insert and one for update
            {
                setting.HoldType = count % 2 == 0 ? 1 : 0;
                setting.HoldUntil = DateTime.Now.AddDays(count);
                setting.UserWeatherSavingAlgorithm = count % 2 == 0 ? true : false;
                setting.UseSiteSessionSettings = count % 2 == 0 ? true : false;
                Assert.IsTrue(Repository.DeviceSettings_Update(device.SN, setting));
                var setting_db = Repository.Settings_Get(device.SN);

                Assert.IsTrue(setting_db.HoldType == setting.HoldType);
                Assert.IsTrue(ComperDate(setting_db.HoldUntil.Value, setting.HoldUntil.Value));
                Assert.IsTrue(setting_db.UserWeatherSavingAlgorithm == setting.UserWeatherSavingAlgorithm);
                Assert.IsTrue(setting_db.UseSiteSessionSettings == setting.UseSiteSessionSettings);

                count++;
            }

        }


        [TestMethod()]
        public void AlertSettingsTest()
        {
            var device = CreateDevice();
            var alert = Repository.AlertDeviceSettings_Get(device.SN);
            var count = 0;
            while (count < 2)///one for insert and one for update
            {
                var alert_ToDB = new List<Models.Device.AlertsSetting>();
                for (int i = 0; i < alert.Length; i++)
                {
                    alert_ToDB.Add(new Models.Device.AlertsSetting { AlertCode = alert[i].AlertCode, SN = device.SN, IsEnable = true, SendEmail = false, SendSMS = true });
                    Assert.IsTrue(Repository.AlertSettings_Update(device.SN, alert_ToDB[i]));
                }

                alert = Repository.AlertDeviceSettings_Get(device.SN);
                Assert.IsTrue(alert != null || alert.Length != 0);
                Assert.IsTrue(alert.Length == alert_ToDB.Count);

                for (int i = 0; i < alert_ToDB.Count; i++)
                {
                    var item_DB = alert_ToDB[i];
                    var item = alert[i];
                    Assert.IsTrue(item_DB.AlertCode == item.AlertCode);
                    Assert.IsTrue(item_DB.IsEnable == item.IsEnable);
                    Assert.IsTrue(item_DB.SendEmail == item.SendEmail);
                    Assert.IsTrue(item_DB.SendSMS == item.SendSMS);
                    Assert.IsTrue(item_DB.SN == item.SN);
                }
                count++;
            }
        }

        [TestMethod()]
        public void DaySettingsTest()
        {
            var device = CreateDevice();
           
            List<Models.Device.DaySettings> setting = null;
            var count = 0;
            while (count < 2)///one for insert and one for update
            {
                setting = new List<Models.Device.DaySettings>();
                var bit = count % 2 == 0;
                for (int i = 0; i < 7; i++)
                {
                    for (int j = 0; j < 6; j++)
                    {
                        setting.Add(new Models.Device.DaySettings() { DayIndex = (byte)i, IrrigationAllowed = bit, MaxDailyCycles = j, Time = 120 *j});
                    }
                    Assert.IsTrue(Repository.DaySettings_Update(device.SN, setting.FirstOrDefault(d => d.DayIndex == i), setting.Where(d => d.DayIndex == i)
                                                                                                                         .Select(t => new TimeValueItem() { Time = t.Time, Allowed = t.IrrigationAllowed }).ToList()));
                }
               
               

                var day_db = Repository.DaySetting_Get(device.SN);
                Assert.IsTrue(day_db != null || day_db.Length != 0);
                Assert.IsTrue(day_db.Length == setting.Count);

                for (int i = 0; i < day_db.Length; i++)
                {
                    var item_DB = day_db[i];
                    var item = day_db.FirstOrDefault(d => d.DayIndex == item_DB.DayIndex && item_DB.Time == d.Time);
                    Assert.IsTrue(item!=null);
                    Assert.IsTrue(item_DB.IrrigationAllowed == item.IrrigationAllowed);
                    Assert.IsTrue(item_DB.MaxDailyCycles == item.MaxDailyCycles);
                    Assert.IsTrue(item_DB.Name == item.Name);
                }
                count++;
            }

        }


        [TestMethod()]
        public void IrrigatingSettingsTest()
        {
            var device = CreateDevice();
            Models.Device.IrrigatingSettings setting = new Models.Device.IrrigatingSettings();
            var count = 0;
            while (count < 2)///one for insert and one for update
            {
                setting.IrrigationFactor = count % 2 == 0 ? 10 : 20;
                setting.ZoneCloseDelay = count % 2 == 0 ? 11 : 21;
                setting.MasterCloseSequence = (byte)(count % 2 == 0 ? 1 : 2);
                setting.MasterOpenSequence = (byte)(count % 2 == 0 ? 2 : 1);
                setting.ZonesOverlapTime = (count % 2 == 0 ? 20 : 30);
                setting.ZoneOpenDelay = (byte)(count % 2 == 0 ? 21 : 31);
                Assert.IsTrue(Repository.IrrigatingSettings_Update(device.SN, setting));
                var setting_db = Repository.IrrigatingSettings_Get(device.SN);

                Assert.IsTrue(setting_db.IrrigationFactor == setting.IrrigationFactor);
                Assert.IsTrue(setting_db.MasterCloseSequence == setting.MasterCloseSequence);
                Assert.IsTrue(setting_db.MasterOpenSequence == setting.MasterOpenSequence);
                Assert.IsTrue(setting_db.ZoneCloseDelay == setting.ZoneCloseDelay);
                Assert.IsTrue(setting_db.ZoneOpenDelay == setting.ZoneOpenDelay);
                Assert.IsTrue(setting_db.ZonesOverlapTime == setting.ZonesOverlapTime);

                count++;
            }
        }

        [TestMethod()]
        public void DisplaySettingsTest()
        {
            var device = CreateDevice();
            Models.Device.DisplaySettings setting = new Models.Device.DisplaySettings();
            var count = 0;
            while (count < 2)///one for insert and one for update
            {
                setting.ClockType = (byte)(count % 2 == 0 ? 1 : 2);
                setting.DisplayCharset = count % 2 == 0 ? 11 : 21;
                setting.TemperatureType = (byte)(count % 2 == 0 ? 1 : 2);
                Assert.IsTrue(Repository.DisplaySettings_Update(device.SN, setting));

                var setting_db = Repository.DisplaySettings_Get(device.SN);
                Assert.IsTrue(setting_db.ClockType == setting.ClockType);
                Assert.IsTrue(setting_db.DisplayCharset == setting.DisplayCharset);
                Assert.IsTrue(setting_db.TemperatureType == setting.TemperatureType);

                count++;
            }
        }

        [TestMethod()]
        public void RainSensorSettingsTest()
        {
            var device = CreateDevice();
            Models.Device.RainSensorSettings setting = new Models.Device.RainSensorSettings();
            var count = 0;
            while (count < 2)///one for insert and one for update
            {
                setting.IsEnabled = (count % 2 == 0 ? true : false);
                setting.RainOffMinDuration = count % 2 == 0 ? 11 : 21;
                setting.RainStabilitySecTime = (byte)(count % 2 == 0 ? 1 : 2);
                setting.SensorInputNumber = (byte)(count % 2 == 0 ? 1 : 2);
                setting.SensorType = (byte)(count % 2 == 0 ? 1 : 2);

                Assert.IsTrue(Repository.RainSensorSettings_Update(device.SN, setting));

                var setting_db = Repository.RainSensorSettings_Get(device.SN);
                Assert.IsTrue(setting_db.IsEnabled == setting.IsEnabled);
                Assert.IsTrue(setting_db.RainOffMinDuration == setting.RainOffMinDuration);
                Assert.IsTrue(setting_db.RainStabilitySecTime == setting.RainStabilitySecTime);
                Assert.IsTrue(setting_db.SensorInputNumber == setting.SensorInputNumber);
                Assert.IsTrue(setting_db.SensorType == setting.SensorType);

                count++;
            }
        }

        [TestMethod()]
        public void FlowSensorSettingsTest()
        {
            var device = CreateDevice();
            Models.Device.FlowSensorSettings setting = new Models.Device.FlowSensorSettings();
            var count = 0;
            while (count < 2)///one for insert and one for update
            {
                setting.IsEnabled = (count % 2 == 0 ? true : false);
                setting.Pulse_PulseSize = count % 2 == 0 ? 19 : 29;
                setting.Pulse_PulseType = (byte)(count % 2 == 0 ? 100 : 29);
                setting.SensorInputNumber = (byte)(count % 2 == 0 ? 1 : 2);
                setting.SensorType = (byte)(count % 2 == 0 ? 1 : 2);
                setting.DI_KValue = (count % 2 == 0 ? 10 : 20);
                setting.DI_OffsetValue = (count % 2 == 0 ? 111 : 222);

                Assert.IsTrue(Repository.FlowSensorSettings_Update(device.SN, setting));

                var setting_db = Repository.FlowSensorSettings_Get(device.SN);
                Assert.IsTrue(setting_db.IsEnabled == setting.IsEnabled);
                Assert.IsTrue(setting_db.DI_KValue == setting.DI_KValue);
                Assert.IsTrue(setting_db.DI_OffsetValue == setting.DI_OffsetValue);
                Assert.IsTrue(setting_db.Pulse_PulseSize == setting.Pulse_PulseSize);
                Assert.IsTrue(setting_db.Pulse_PulseType == setting.Pulse_PulseType);
                Assert.IsTrue(setting_db.SensorInputNumber == setting.SensorInputNumber);
                Assert.IsTrue(setting_db.SensorType == setting.SensorType);

                count++;
            }
        }


        [TestMethod()]
        public void AlertThresholdSettingsTest()
        {
            var device = CreateDevice();
            Models.Device.AlertThresholdSettings setting = new Models.Device.AlertThresholdSettings();
            var count = 0;
            while (count < 2)///one for insert and one for update
            {
                setting.OverCurrentThreshold = count % 2 == 0 ? 19 : 29;
                setting.UnderCurrentThreshold = (byte)(count % 2 == 0 ? 100 : 29);

                Assert.IsTrue(Repository.AlertThresholdSettings_Update(device.SN, setting));

                var setting_db = Repository.AlertThresholdSettings_Get(device.SN);
                Assert.IsTrue(setting_db.OverCurrentThreshold == setting.OverCurrentThreshold);
                Assert.IsTrue(setting_db.UnderCurrentThreshold == setting.UnderCurrentThreshold);

                count++;
            }
        }

        #endregion

        #region Schedule

        [TestMethod()]
        public void UpdateScheduleTypeTest()
        {
            var device = CreateDevice();
            Assert.IsTrue(Repository.ScheduleType_Update(device.SN, 1));
            var device_Schedule = Repository.IrrigationSchedule_Get(device.SN, null);
            Assert.IsTrue(device_Schedule.ScheduleType == 1);

            Assert.IsTrue(Repository.ScheduleType_Update(device.SN, 2));
            device_Schedule = Repository.IrrigationSchedule_Get(device.SN, null);
            Assert.IsTrue(device_Schedule.ScheduleType == 2);

            Assert.IsTrue(Repository.ScheduleType_Update(device.SN, 3));
            device_Schedule = Repository.IrrigationSchedule_Get(device.SN, null);
            Assert.IsTrue(device_Schedule.ScheduleType == 3);
        }

        [TestMethod()]
        public void IrrigationScheduleTest()
        {
            //in device mode 
            String SN = "";
            var zones = GetDeviceZones(out SN);
            #region Weekly
            {

                Assert.IsTrue(Repository.ScheduleType_Update(SN, 1));
                List<Models.Device.IrrigationScheduleItem> items = new List<Models.Device.IrrigationScheduleItem>();

                int count_Save = 0;
                int count_time = 0;
                //For 7 days add 10 start time for 4 zones
                while (count_Save < 2)
                {
                    for (int i = 0; i < 7; i++)
                    {
                        while (count_time < 6)
                        {
                            for (int X = 0; X < zones.Length; X++)
                            {
                                if (count_Save % 2 == 0)
                                    items.Add(new Models.Device.IrrigationScheduleItem { DayNum = i, Quantity = i * 22, StartTime = count_time * 20, Time = 50, ZoneNum = zones[X].Number });
                                else
                                    items.Add(new Models.Device.IrrigationScheduleItem { DayNum = i, Quantity = i * 11, StartTime = count_time * 14, Time = 20, ZoneNum = zones[X].Number });
                            }
                            count_time++;
                        }

                        count_time = 0;
                    }

                    Assert.IsTrue(Repository.IrrigationSchedule_Items_Update(SN, items, 1));
                    var list_db = Repository.IrrigationSchedule_Get(SN, null); //save in device the type
                    Assert.IsTrue(list_db.ScheduleItems.Count == items.Count);
                    for (int i = 0; i < list_db.ScheduleItems.Count; i++)
                    {
                        var item = list_db.ScheduleItems[i];
                        var soruce = items.FirstOrDefault(d => d.DayNum == item.DayNum
                                                          && d.ZoneNum == item.ZoneNum
                                                          && d.StartTime == item.StartTime);
                        Assert.IsTrue(soruce != null);
                        Assert.IsTrue(soruce.Quantity == item.Quantity);
                        Assert.IsTrue(soruce.Time == item.Time);
                        

                    }

                    #region By Day
                    for (int i = 0; i < 7; i++)
                    {
                        var _day = items.Where(d => d.DayNum == i).ToList();
                        var list_db_By_Day = Repository.IrrigationSchedule_GetByDay(SN, i, 1);
                        Assert.IsTrue(_day.Count == list_db_By_Day.ScheduleItems.Count);
                        foreach (var item_day in _day)
                        {
                            var d = list_db_By_Day.ScheduleItems.FirstOrDefault(c => c.ZoneNum == item_day.ZoneNum && c.StartTime == item_day.StartTime);
                            Assert.IsTrue(d != null);
                            Assert.IsTrue(d.Quantity == item_day.Quantity);
                            Assert.IsTrue(d.Time == item_day.Time);
                        }

                    }


                    #endregion

                    #region By Zone
                    foreach (var zone in zones)
                    {
                        var list_zones_db = Repository.IrrigationSchedule_GetByZone(SN, zone.Number, null);
                        foreach (var item in list_zones_db.ScheduleItems)
                        {
                            var soruce = items.FirstOrDefault(d => d.DayNum == item.DayNum
                                                         && d.ZoneNum == item.ZoneNum
                                                         && d.StartTime == item.StartTime);
                            Assert.IsTrue(soruce != null);
                            Assert.IsTrue(soruce.Quantity == item.Quantity);
                            Assert.IsTrue(soruce.Time == item.Time);

                        }
                        

                    }
                    #endregion

                    items = new List<Models.Device.IrrigationScheduleItem>();
                    count_Save++;
                }




            }
            #endregion

            #region odd/even
            {
                Assert.IsTrue(Repository.ScheduleType_Update(SN, 2));
                List<Models.Device.IrrigationScheduleItem> items = new List<Models.Device.IrrigationScheduleItem>();

                int count_Save = 0;
                int count_time = 0;
                //For 7 days add 10 start time for 4 zones
                while (count_Save < 2)
                {
                    for (int i = 0; i < 7; i++)
                    {
                        while (count_time < 6)
                        {
                            for (int X = 0; X < zones.Length; X++)
                            {
                                if (count_Save % 2 == 0)
                                    items.Add(new Models.Device.IrrigationScheduleItem
                                    {
                                        DayNum = i,
                                        Quantity = i * 22,
                                        StartTime = count_time * 20,
                                        Time = 50,
                                        ZoneNum = zones[X].Number
                                    });
                                else
                                    items.Add(new Models.Device.IrrigationScheduleItem
                                    {
                                        DayNum = i,
                                        Quantity = i * 11,
                                        StartTime = count_time * 14,
                                        Time = 20,
                                        ZoneNum = zones[X].Number
                                    });
                            }
                            count_time++;
                        }

                        count_time = 0;
                    }

                    Assert.IsTrue(Repository.IrrigationSchedule_Items_Update(SN, items, 2));
                    var list_db = Repository.IrrigationSchedule_Get(SN, null); //save in device the type
                    Assert.IsTrue(list_db.ScheduleItems.Count == items.Count);
                    for (int i = 0; i < list_db.ScheduleItems.Count; i++)
                    {
                        var item = list_db.ScheduleItems[i];
                        var soruce = items.FirstOrDefault(d => d.DayNum == item.DayNum
                                                          && d.ZoneNum == item.ZoneNum
                                                          && d.StartTime == item.StartTime);
                        Assert.IsTrue(soruce != null);
                        Assert.IsTrue(soruce.Quantity == item.Quantity);
                        Assert.IsTrue(soruce.Time == item.Time);

                    }


                    #region By Zone
                    foreach (var zone in zones)
                    {
                        var list_zones_db = Repository.IrrigationSchedule_GetByZone(SN, zone.Number, null);
                        foreach (var item in list_zones_db.ScheduleItems)
                        {
                            var soruce = items.FirstOrDefault(d => d.DayNum == item.DayNum
                                                         && d.ZoneNum == item.ZoneNum
                                                         && d.StartTime == item.StartTime);
                            Assert.IsTrue(soruce != null);
                            Assert.IsTrue(soruce.Quantity == item.Quantity);
                            Assert.IsTrue(soruce.Time == item.Time);

                        }


                    }
                    #endregion


                    items = new List<Models.Device.IrrigationScheduleItem>();
                    count_Save++;
                }
            }
            #endregion



        }
        #endregion

        [TestMethod()]
        public void DeleteAllIrrigationScheduleByTypeTest()
        {
            Assert.Fail();
        }

        #region Device

        //[TestMethod()]
        //public void ConfirmDeviceCodeTest()
        //{
        //    var code = Guid.NewGuid().ToString();
        //    var device = CreateDevice(code);
        //    Assert.IsTrue(Repository.ConfirmDeviceCode(device.SN, code));
        //    Assert.IsFalse(Repository.ConfirmDeviceCode(device.SN, "33"));
        //}

        [TestMethod()]
        public void AddDeviceTest()
        {
            Assert.Fail();
        }

        [TestMethod()]
        public void GetDeviceTest()
        {
            var device = CreateDevice();
            var device_db = Repository.GetDevice(device.SN);
            Assert.AreEqual(device_db.Name , device.Name);
            Assert.AreEqual(device_db.ModelID , device.ModelID);
            Assert.AreEqual(device_db.Map_Latitude , device.Map_Latitude);
            Assert.AreEqual(device_db.Map_Longitude, device.Map_Longitude);
            Assert.AreEqual(device_db.SN , device.SN);
            Assert.AreEqual(device_db.ActivatedZones , device.ActivatedZones);
            Assert.AreEqual(device_db.MaxZones, device.MaxZones);
            Assert.AreEqual(device_db.CurrentConfigID , device.CurrentConfigID);
            //Assert.IsTrue(device_db.DefaultRemoteSystemID == device.DefaultRemoteSystemID);
            Assert.IsTrue(device_db.DeviceID == device.DeviceID);
        }

        #endregion

        #region Zone

        [TestMethod()]
        public void UpdateZoneTest()
        {
            string SN = "";
            var zoneList = GetDeviceZones(out SN);
            for (int i = 0; i < zoneList.Length; i++)
            {
                var item = zoneList[i];
                var count = 0;
                while (count < 2)
                {
                    count++;
                    item.ImageURI = "ImageURI_" + i.ToString();
                    item.IsEnabled = i % 2 == 0;
                    item.Name = "Name" + i.ToString();
                    Assert.IsTrue(Repository.Zone_Name_Update(SN, item.Number, item.Name));
                    Assert.IsTrue(Repository.ActiveZone_Update(SN, item.Number, item.IsEnabled));
                    Assert.IsTrue(Repository.Zone_Image_Update(SN, item.Number, item.ImageURI));

                    var zone_db = Repository.GetZone(SN, item.Number);
                    Assert.IsTrue(item.Name == zone_db.Name);
                    Assert.IsTrue(item.IsEnabled == zone_db.IsEnabled);
                    Assert.IsTrue(item.ImageURI == zone_db.ImageURI);
                }

            }
        }



        [TestMethod()]
        public void ZoneSettingsTest()
        {
            string SN = "";
            var zoneList = GetDeviceZones(out SN);
            for (int i = 0; i < zoneList.Length; i++)
            {
                var item = zoneList[i];
                var count = 0;
                Models.Zone.ZoneIrrigationSettings setting = new Models.Zone.ZoneIrrigationSettings();
                while (count < 2)///one for insert and one for update
                {
                    setting.IrrigationFactor = count % 2 == 0 ? 19 : 29;
                    setting.MaxCycleTime = (byte)(count % 2 == 0 ? 100 : 29);
                    setting.MaxSoakTime = (byte)(count % 2 == 0 ? 110 : 11);
                    setting.UserWeatherAlgorithm = (count % 2 != 0);
                    setting.WireColor = (count % 2 == 0 ? "100" : "29");
                    setting.IsEnabled = (count % 2 == 0);

                    Assert.IsTrue(Repository.Zone_UpdateSettings(SN, item.Number, setting));
                    Assert.IsTrue(Repository.Zone_SoakSettings_Update(SN, item.Number, setting.MaxCycleTime, setting.MaxSoakTime));

                    var setting_db = Repository.ZoneSettings_Get(SN, item.Number);
                    Assert.IsTrue(setting_db.IrrigationFactor == setting.IrrigationFactor);
                    Assert.IsTrue(setting_db.IsEnabled == setting.IsEnabled);
                    Assert.IsTrue(setting_db.MaxCycleTime == setting.MaxCycleTime);
                    Assert.IsTrue(setting_db.MaxSoakTime == setting.MaxSoakTime);
                    Assert.IsTrue(setting_db.UserWeatherAlgorithm == setting.UserWeatherAlgorithm);
                    Assert.IsTrue(setting_db.WireColor == setting.WireColor);


                    count++;
                }
            }
        }

        [TestMethod()]
        public void FlowSensorSettingsTest1()
        {
            string SN = "";
            var zoneList = GetDeviceZones(out SN);
            Models.Zone.ZoneFlowSensorSettings setting = null;
            for (int i = 0; i < zoneList.Length; i++)
            {
                var item = zoneList[i];
                var count = 0;
                setting = new Models.Zone.ZoneFlowSensorSettings();
                while (count < 2)///one for insert and one for update
                {
                    setting.LastObservedFlow = count % 2 == 0 ? 19 : 29;
                    setting.NominalFlow = (count % 2 == 0 ? 100.9m : 29.8m);
                    setting.ThresholdOverFlow = (count % 2 == 0 ? 110 : 11);
                    setting.ThresholdUnderFlow = (count % 2 != 0 ? 2 : 99);
                    setting.TimeFillDelay = (count % 2 == 0 ? 55 : 33);

                    Assert.IsTrue(Repository.Zone_FlowSensorSettings_Update(SN, item.Number, setting));

                    var setting_db = Repository.FlowSensorSettings_Get(SN, item.Number);
                    Assert.IsTrue(setting_db.LastObservedFlow == setting.LastObservedFlow);
                    Assert.IsTrue(setting_db.NominalFlow == setting.NominalFlow);
                    Assert.IsTrue(setting_db.ThresholdOverFlow == setting.ThresholdOverFlow);
                    Assert.IsTrue(setting_db.ThresholdUnderFlow == setting.ThresholdUnderFlow);
                    Assert.IsTrue(setting_db.TimeFillDelay == setting.TimeFillDelay);

                    count++;
                }
            }
        }

        [TestMethod()]
        public void IrrigationSuggestionsTest()
        {
            string SN = "";
            var zoneList = GetDeviceZones(out SN);
            Models.Zone.ZoneIrrigationSuggestion setting = null;
            for (int i = 0; i < zoneList.Length; i++)
            {
                var item = zoneList[i];
                var count = 0;
                setting = new Models.Zone.ZoneIrrigationSuggestion();
                while (count < 2)///one for insert and one for update
                {
                    setting.Number = item.Number;
                    setting.Suggestion_MaximumCycleMinutes = count % 2 == 0 ? 19 : 29;
                    setting.Suggestion_RunTimeDaily = (count % 2 == 0 ? 100 : 29);
                    setting.Suggestion_SoakTimeMinutes = (count % 2 == 0 ? 110 : 11);
                    setting.Suggestion_TotalMonthMinutes = (count % 2 != 0 ? 2 : 99);
                    setting.Suggestion_TotalWeeklyDays = (count % 2 == 0 ? 55 : 33);
                    setting.Suggestion_TotalWeeklyMinutes = (count % 2 == 0 ? 22 : 44);

                    Assert.IsTrue(Repository.IrrigationSuggestion_Update(SN, setting));

                    var setting_db = Repository.IrrigationSuggestions_Get(SN, item.Number);
                    Assert.IsTrue(setting_db.Suggestion_MaximumCycleMinutes == setting.Suggestion_MaximumCycleMinutes);
                    Assert.IsTrue(setting_db.Suggestion_RunTimeDaily == setting.Suggestion_RunTimeDaily);
                    Assert.IsTrue(setting_db.Suggestion_SoakTimeMinutes == setting.Suggestion_SoakTimeMinutes);
                    Assert.IsTrue(setting_db.Suggestion_TotalMonthMinutes == setting.Suggestion_TotalMonthMinutes);
                    Assert.IsTrue(setting_db.Suggestion_TotalWeeklyDays == setting.Suggestion_TotalWeeklyDays);
                    Assert.IsTrue(setting_db.Suggestion_TotalWeeklyMinutes == setting.Suggestion_TotalWeeklyMinutes);

                    count++;
                }

                Assert.IsFalse(setting.IsAccepted);
                Assert.IsTrue(Repository.IrrigationSuggestion_Accept(SN, item.Number));
                var setting_Accept = Repository.IrrigationSuggestions_Get(SN, item.Number);
                Assert.IsTrue(setting_Accept.IsAccepted);



            }
        }

        //public enum AdvisorTypes : int
        //{
        //    PlantType = 0,
        //    SprinklerType = 1,
        //    SlopeType = 2,
        //    SoilType = 3,
        //    SunExposureType = 4
        //}

        [TestMethod()]
        public void CategoriesTest()
        {
            var plant = Repository.GetPlantTypes();
            var soil = Repository.GetSoilTypes();
            var sun = Repository.GetSunExposureTypes();
            var sprinkl = Repository.GetSprinklTypes();
            var slope = Repository.GetSlopeType();
            Assert.IsTrue(plant != null && plant.Length > 0
                && soil != null && soil.Length > 0
                && sun != null && sun.Length > 0
                && sprinkl != null && sprinkl.Length > 0
                && slope != null && slope.Length > 0);

            string SN = "";
            var zoneList = GetDeviceZones(out SN);
            for (int i = 0; i < zoneList.Length; i++)
            {
                var item = zoneList[i];
                var count = 0;
                Models.Zone.Categories[] Categories = new Models.Zone.Categories[5];
                while (count < 2)///one for insert and one for update
                {
                    count++;
                    //plant
                    var p = plant.FirstOrDefault(t => t.ID % 2 == 0);
                    Categories[0] = new Models.Zone.Categories()
                    {
                        TypeID = 0,//(int)AdvisorTypes.PlantType,
                        SubTypeID = p.ID
                    };

                    var sp = sprinkl.FirstOrDefault(t => t.ID % 2 == 0);
                    //SprinklerType
                    Categories[1] = new Models.Zone.Categories()
                    {
                        TypeID = 1,//(int)AdvisorTypes.SprinklerType,
                        SubTypeID = sp.ID
                    };

                    var sl = slope.FirstOrDefault(t => t.ID % 2 == 0);
                    //SlopeType
                    Categories[2] = new Models.Zone.Categories()
                    {
                        TypeID = 2,//(int)AdvisorTypes.SlopeType,
                        SubTypeID = sl.ID
                    };

                    var so = soil.FirstOrDefault(t => t.ID % 2 == 0);
                    //SoilType
                    Categories[3] = new Models.Zone.Categories()
                    {
                        TypeID = 3,//(int)AdvisorTypes.SoilType,
                        SubTypeID = so.ID
                    };

                    var su = sun.FirstOrDefault(t => t.ID % 2 == 0);
                    //SunExposureType
                    Categories[4] = new Models.Zone.Categories()
                    {
                        TypeID = 4,//(int)AdvisorTypes.SunExposureType,
                        SubTypeID = su.ID
                    };

                    for (int j = 0; j < 5; j++)
                    {
                        Assert.IsTrue(Repository.Categories_Update(SN, item.Number, Categories[j]));
                    }

                    var list = Repository.Categories_Get(SN, item.Number);
                    for (int x = 0; x < list.Length; x++)
                    {
                        var c = Categories.FirstOrDefault(s => s.TypeID == list[x].TypeID);
                        Assert.IsTrue(c != null && c.SubTypeID == list[x].SubTypeID);
                    }

                }
            }

        }

        #endregion
    }
}