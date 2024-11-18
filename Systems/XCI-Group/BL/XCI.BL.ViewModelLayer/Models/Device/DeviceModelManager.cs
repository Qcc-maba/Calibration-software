using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Settings;
using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device;
using System.Reflection;
using Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Schedule;
using static Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Schedule.BaseDeviceScheduleView;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device
{
    public class DeviceModelManager : ViewModelManager.BaseViewModelManager
    {
        #region members

        private DAL.DataAccessLayer.Repositories.Admin.IAdminRepository _AdminRepository = null;

        public delegate void ExceptionDelegate(object sender, UnhandledExceptionEventArgs e);
        public event ExceptionDelegate OnException;

        #endregion

        #region ctor

        public DeviceModelManager(ViewModelLayer.Settings.ViewModelLayerSettings currentSettings)
            : base(currentSettings)
        {
            _AdminRepository = currentSettings.AdminRepositoryFunc();
        }

        #endregion

        protected void ThrowException(Exception e)
        {
            if (OnException != null)
            {
                OnException(this, new UnhandledExceptionEventArgs(e, false));
            }
            else
            {
                throw e;
            }
        }

        #region BaseViewModelManager members

        protected override void OnDispose()
        {
            if (_AdminRepository != null)
            {
                this._AdminRepository.Dispose();
            }
        }

        #endregion

        public long? AddDevice(string SN, int? ModelID)
        {
            long? deviceID = _AdminRepository.AddDevice(SN, ModelID);
            if (deviceID == null || deviceID == -1)
            {
                ThrowException(new Exception());
            }
            return deviceID;
        }

        public Settings.DeviceSettingsView GetDeviceSettings(string SN)
        {
            Settings.DeviceSettingsViewBase Settings = null;
            Settings.IrrigatingSettingsView IrrigatingSettings = null;
            Settings.DisplaySettingsView DisplaySettings = null;
            Settings.RainSensorSettingsView RainSensorSettings = null;
            Settings.FlowSensorSettingsView FlowSensorSettings = null;
            Schedule.BaseDeviceScheduleView DeviceSchedule = null;
            Settings.AlertThresholdSettingsView AlertThresholdSettings = null;

            var DeviceSettings = _AdminRepository.Settings_Get(SN);
            var DaySetting = _AdminRepository.DaySetting_Get(SN);
            Settings = new Settings.DeviceSettingsViewBase(DeviceSettings, DaySetting);

            var _IrrigatingSettings = _AdminRepository.IrrigatingSettings_Get(SN);
            IrrigatingSettings = _IrrigatingSettings == null ? IrrigatingSettingsView.CreateDefault() : new IrrigatingSettingsView(_IrrigatingSettings);

            var _DisplaySettings = _AdminRepository.DisplaySettings_Get(SN);
            DisplaySettings = _DisplaySettings == null ? DisplaySettingsView.CreateDefault() : new DisplaySettingsView(_DisplaySettings);

            var _RainSensorSettings = _AdminRepository.RainSensorSettings_Get(SN);
            RainSensorSettings = _RainSensorSettings == null ? RainSensorSettingsView.CreateDefault() : new RainSensorSettingsView(_RainSensorSettings);

            var _FlowSensorSettings = _AdminRepository.FlowSensorSettings_Get(SN);
            FlowSensorSettings = _FlowSensorSettings == null ? FlowSensorSettingsView.CreateDefault() : new FlowSensorSettingsView(_AdminRepository.FlowSensorSettings_Get(SN));

            var _AlertThresholdSettings = _AdminRepository.AlertThresholdSettings_Get(SN);
            AlertThresholdSettings = _AlertThresholdSettings == null ? AlertThresholdSettingsView.CreateDefault() : new AlertThresholdSettingsView(_AlertThresholdSettings);

            DeviceSchedule = GetIrrigationSchedule(SN, null);

            return new Settings.DeviceSettingsView()
            {
                DeviceSettings = Settings,
                IrrigatingSettings = IrrigatingSettings,
                RainSensorSettings = RainSensorSettings,
                DisplaySettings = DisplaySettings,
                FlowSensorSettings = FlowSensorSettings,
                IrrigationSchedule = DeviceSchedule,
                AlertThresholdSettings = AlertThresholdSettings
            };
        }


        public bool UpdateAlertSettings(string SN, AlertSettingsView[] device_Settings)
        {
            var result = false;
            foreach (var item_main in device_Settings)
            {
                var item = item_main.Device_Settings;
                result = _AdminRepository.AlertSettings_Update(SN, new AlertsSetting()
                {
                    AlertCode = item.AlertCode,
                    IsEnable = item.IsEnable,
                    SendEmail = item.SendEmail,
                    SendSMS = item.SendSMS
                });
                if (!result)
                    return result;
            }

            return result;
        }

        public bool UpdateAlertThresholdSettings(string SN, AlertThresholdSettingsView setting)
        {
            return _AdminRepository.AlertThresholdSettings_Update(
                                                                SN,
                                                                new AlertThresholdSettings()
                                                                {
                                                                    OverCurrentThreshold = setting.OverCurrentThreshold,
                                                                    UnderCurrentThreshold = setting.UnderCurrentThreshold,
                                                                    IsAlertsEnabled = setting.IsAlertsEnabled
                                                                });
        }

        public AlertSettingsView[] GetAlertSettings(string SN, bool SendDefaults)
        {
            return _AdminRepository.AlertDeviceSettings_Get(SN).Select(u => new AlertSettingsView(u, SendDefaults)).ToArray();
        }

        public bool UpdateDeviceLocation(string SN, string lat, string lon)
        {
            return _AdminRepository.UpdateDeviceLocation(SN, lat, lon);
        }

        public bool Test()
        {
            return _AdminRepository.Test();
        }

        public bool UpdateDeviceSettings(string SN, Settings.DeviceSettingsView setting)
        {
            bool result = false;
            if (setting == null)
                return result;
            if (setting.DeviceSettings != null)
            {
                result = _AdminRepository.DeviceSettings_Update(SN, new DeviceSettings()
                {
                    HoldUntil = setting.DeviceSettings.HoldUntil,
                    UserWeatherSavingAlgorithm = setting.DeviceSettings.UserWeatherSavingAlgorithm,
                    UseSiteSessionSettings = setting.DeviceSettings.UseSiteSessionSettings,
                    HoldType = setting.DeviceSettings.HoldType
                });
                if (!result)
                    return result;
            }
            if (setting.DisplaySettings != null)
            {
                result = _AdminRepository.DisplaySettings_Update(SN, new DisplaySettings()
                {
                    ClockType = (byte)setting.DisplaySettings.ClockType,
                    TemperatureType = (byte)setting.DisplaySettings.TemperatureType,
                    DisplayCharset = setting.DisplaySettings.DisplayCharset

                });
                if (!result)
                    return result;
            }

            if (setting.FlowSensorSettings != null)
            {
                result = _AdminRepository.FlowSensorSettings_Update(SN, new FlowSensorSettings()
                {
                    DI_KValue = setting.FlowSensorSettings.DI_KValue,
                    DI_OffsetValue = setting.FlowSensorSettings.DI_OffsetValue,
                    IsEnabled = setting.FlowSensorSettings.IsEnabled,
                    Pulse_PulseSize = setting.FlowSensorSettings.PulseSize,
                    Pulse_PulseType = setting.FlowSensorSettings.PulseType,
                    SensorInputNumber = setting.FlowSensorSettings.SensorInputNumber,
                    SensorType = (byte)setting.FlowSensorSettings.SensorType
                });
                if (!result)
                    return result;
            }
            if (setting.IrrigatingSettings != null)
            {
                result = _AdminRepository.IrrigatingSettings_Update(SN, new IrrigatingSettings()
                {
                    IrrigationFactor = setting.IrrigatingSettings.IrrigationFactor,
                    ZoneCloseDelay = setting.IrrigatingSettings.ZoneCloseDelay,
                    ZoneOpenDelay = setting.IrrigatingSettings.ZoneOpenDelay,
                    ZonesOverlapTime = setting.IrrigatingSettings.ZonesOverlapTime,
                    MasterOpenSequence = (byte)setting.IrrigatingSettings.MasterOpenSequence,
                    MasterCloseSequence = (byte)setting.IrrigatingSettings.MasterCloseSequence
                });
                if (!result)
                    return result;
            }
            if (setting.RainSensorSettings != null)
            {
                result = _AdminRepository.RainSensorSettings_Update(SN, new RainSensorSettings()
                {
                    IsEnabled = setting.RainSensorSettings.IsEnabled,
                    RainOffMinDuration = setting.RainSensorSettings.RainOffMinDuration,
                    RainStabilitySecTime = setting.RainSensorSettings.RainStabilitySecTime,
                    SensorInputNumber = setting.RainSensorSettings.SensorInputNumber,
                    SensorType = (byte)setting.RainSensorSettings.SensorType
                });
                if (!result)
                    return result;
            }
            if (setting.IrrigationSchedule != null)
            {
                switch (setting.IrrigationSchedule.ScheduleType)
                {
                    case Device.Schedule.BaseDeviceScheduleView.ScheduleTypes.Weekly:
                        UpdateDeviceScheduleWeekly(SN, (Schedule.WeeklyScheduleView)setting.IrrigationSchedule);

                        break;
                    case Device.Schedule.BaseDeviceScheduleView.ScheduleTypes.Odd:
                        UpdateDeviceSchedule_ByDay(SN, (Schedule.DailyScheduleView)setting.IrrigationSchedule, Schedule.BaseDeviceScheduleView.ScheduleTypes.Odd);

                        break;
                    case Device.Schedule.BaseDeviceScheduleView.ScheduleTypes.Even:
                        UpdateDeviceSchedule_ByDay(SN, (Schedule.DailyScheduleView)setting.IrrigationSchedule, Schedule.BaseDeviceScheduleView.ScheduleTypes.Even);
                        break;
                    default:
                        UpdateDeviceScheduleWeekly(SN, (Schedule.WeeklyScheduleView)setting.IrrigationSchedule);
                        break;
                }


            }



            return result;
        }

        public AlertThresholdSettingsView GetAlertThresholdSettingsView(string SN)
        {
            return new AlertThresholdSettingsView(_AdminRepository.AlertThresholdSettings_Get(SN));
        }

        public bool UpdateDaySetting(string SN, DaySettingsView[] daysSettingsView)
        {
            var result = false;

            foreach (var DayItem in daysSettingsView)
            {
                var day = new DaySettings()
                {
                    DayIndex = (byte)DayItem.DayIndex,
                    MaxDailyCycles = DayItem.MaxDailyCycles,
                    MaxDailyIrrigrationSeconds = DayItem.MaxDailyIrrigrationSeconds,
                    Name = DayItem.Name,

                };
                result = _AdminRepository.DaySettings_Update(SN, day, DayItem.Times.Select(t => new TimeValueItem() { Time = t.Time, Allowed = t.Allowed }).ToList());

                if (!result)
                    return result;
            }
            return result;
        }

        public const int FIXED_TIMES = 7;
        public List<int> START_TIMES = new List<int>() { 0, 14400, 28800, 43200, 57600, 72000, 86340 };
        public DaySettingsView[] GetDaySettingsView(string SN)
        {
            var list_db = _AdminRepository.DaySetting_Get(SN);
            var _dayf = new List<DaySettingsView>();


            var _days = list_db
                    .OrderBy(g => g.DayIndex)
                    .ThenBy(g => g.Time)
                    .ToArray();

            var _times = list_db.GroupBy(t => t.Time)
                    .Select(t => t.Key)
                    .OrderBy(t => t)
                    .ToList();

            int missingTimes = FIXED_TIMES - _times.Count;

            var lastTime = missingTimes == FIXED_TIMES ? 0 : START_TIMES.FirstOrDefault(t => t > _times[0]);
            for (int i = 0; i < missingTimes; i++)
            {
                _times.Add(lastTime);
                lastTime = START_TIMES.FirstOrDefault(t => t > lastTime);
            }

            byte dindex = 0;
            byte tIndex = 0;

            DaySettingsView item = new DaySettingsView()
            {
                DayIndex = -1,
                Times = new List<TimeValueItem>()
            };

            for (int i = 0; i < _days.Length; i++)
            {
                if (item.DayIndex != _days[i].DayIndex)
                {
                    #region fill times for previous item

                    while (tIndex < FIXED_TIMES && item.Times != null)
                    {
                        item.Times.Add(new TimeValueItem()
                        {
                            Allowed = true,
                            Time = _times[tIndex]
                        });
                        tIndex++;
                    }

                    #endregion

                    #region fill days between dindex and item

                    while (dindex < _days[i].DayIndex)
                    {
                        item = new DaySettingsView()
                        {
                            DayIndex = dindex,
                            Name = "",
                            MaxDailyIrrigrationSeconds = 0,
                            MaxDailyCycles = 0,
                            Times = _times.Select(t => new TimeValueItem() { Allowed = true, Time = t }).ToList()
                        };
                        _dayf.Add(item);
                        dindex++;
                    }

                    #endregion

                    tIndex = 0;

                    item = new DaySettingsView()
                    {
                        DayIndex = _days[i].DayIndex,
                        Name = _days[i].Name,
                        MaxDailyIrrigrationSeconds = _days[i].MaxDailyIrrigrationSeconds,
                        MaxDailyCycles = _days[i].MaxDailyCycles,
                        Times = new List<TimeValueItem>()
                    };

                    dindex++;
                    _dayf.Add(item);
                }

                while (_times[tIndex] < _days[i].Time)
                {
                    item.Times.Add(new TimeValueItem()
                    {
                        Allowed = true,
                        Time = _times[tIndex]
                    });
                    tIndex++;
                }

                item.Times.Add(new TimeValueItem()
                {
                    Allowed = _days[i].IrrigationAllowed,
                    Time = _days[i].Time
                });

                tIndex++;
                // item.IsIrrigationAllowed = item.IsIrrigationAllowed && _days[i].IrrigationAllowed;

            }

            #region fill last item's times

            while (tIndex < FIXED_TIMES)
            {
                item.Times.Add(new TimeValueItem()
                {
                    Allowed = true,
                    Time = _times[tIndex]
                });
                tIndex++;
            }

            item.Times = item.Times.OrderBy(t => t.Time).ToList();

            #endregion

            //fill rest of week
            while (dindex < 7)
            {
                item = new DaySettingsView()
                {
                    DayIndex = dindex,
                    Name = "",
                    MaxDailyIrrigrationSeconds = 0,
                    MaxDailyCycles = 0,
                    //IsIrrigationAllowed = true,
                    Times = _times.Select(t => new TimeValueItem() { Allowed = true, Time = t }).ToList()
                };
                _dayf.Add(item);
                dindex++;
            }

            return _dayf.OrderBy(d => d.DayIndex).ToArray();
        }

        public DeviceView GetDevice(string SN)
        {
            var device = _AdminRepository.GetDevice(SN);

            return device == null ? null : new DeviceView(device);
        }

        public DeviceViewWithSettings GetDeviceWithSettings(string SN)
        {
            var device = _AdminRepository.GetDevice(SN);
            if (device != null)
            {
                var _settings = GetDeviceSettings(SN);
                return new DeviceViewWithSettings(device, _settings);
            }
            return null;
        }

        #region IrrigationSchedule
        public Schedule.BaseDeviceScheduleView GetIrrigationSchedule(string SN, byte? ScheduleType)
        {
            var deviceZones = _AdminRepository.GetDeviceZones(SN).Where(u => u.IsEnabled == true).ToArray();
            var IrrigationSchedule = _AdminRepository.IrrigationSchedule_Get_OverStartTime(SN, ScheduleType);
            switch ((ScheduleTypes)IrrigationSchedule.ScheduleType)
            {
                case ScheduleTypes.Weekly:
                    return GetWeeklyScheduleView(deviceZones, IrrigationSchedule.ScheduleItems, _AdminRepository.DaySetting_Get(SN));
                case ScheduleTypes.Odd:
                case ScheduleTypes.Even:
                    return GetDailyScheduleView(deviceZones, IrrigationSchedule);
                default:
                    return GetDailyScheduleView(deviceZones, IrrigationSchedule);
            }

        }

        public WeeklyScheduleView GetWeeklyScheduleView(DAL.DataAccessLayer.Models.Zone.ZoneList[] ZoneList, List<DAL.DataAccessLayer.Models.Device.IrrigationScheduleItem> ScheduleItems, DAL.DataAccessLayer.Models.Device.DaySettings[] daySettings)
        {
            var Weekly = new WeeklyScheduleView();
            Weekly.ScheduleType = ScheduleTypes.Weekly;

            #region Get Days

            var WeeklyTemp_TitleDays = Enumerable
                                       .Range(0, 7)
                                       .Select(i => new ScheduleDayTitle() { DayNumber = i, FirstStartTime = -1, NumOfStartTime = 0 }).ToArray();


            var dayIndex = -1;
            var day_Item = new ScheduleDayTitle();

            foreach (var item in daySettings)
            {
                if (dayIndex != item.DayIndex)
                {
                    day_Item = new ScheduleDayTitle()
                    {
                        DayNumber = item.DayIndex,
                        SettingsView = new DaySettingsView()
                        {
                            Times = new List<TimeValueItem>()
                        }
                    };

                    WeeklyTemp_TitleDays[item.DayIndex] = day_Item;
                    dayIndex = item.DayIndex;
                }
                day_Item.SettingsView.Times.Add(new TimeValueItem() { Time = item.Time, Allowed = item.IrrigationAllowed });
            }

            Weekly.TitleDays = WeeklyTemp_TitleDays;


            #endregion

            #region build  zones

            WeeklyScheduleZone[] WeeklyScheduleZones = ZoneList.Select(i => new WeeklyScheduleZone()
            {
                ZoneNumber = i.Number,
                Name = i.Name,
                Days = Enumerable.Range(0, 7).Select(d => new WeeklyScheduleZone2Day()
                {
                    //IsAllowedDay = Weekly.TitleDays[d].SettingsView != null ? Weekly.TitleDays[d].SettingsView.IsIrrigationAllowed() : true,
                    Duration = 0,
                    Quantity = 0
                }
               ).ToArray()
            }
            ).ToArray();

            var lastStartTime = -1;
            var lastDay = -1;
            var zoneIndex = -1;
            WeeklyScheduleZone zoneItem = null;
            ScheduleDayTitle dayItem = null;

            foreach (var item in ScheduleItems)
            {
                if (lastStartTime != item.StartTime)
                {
                    lastDay = item.DayNum;
                    zoneIndex = 0;
                    lastStartTime = item.StartTime;
                    lastDay = -1;
                }

                dayItem = WeeklyTemp_TitleDays[item.DayNum];



                if (lastDay < dayItem.DayNumber)
                {
                    lastDay = dayItem.DayNumber;
                    if (dayItem.FirstStartTime != -1)
                    {
                        dayItem.NumOfStartTime++;
                    }
                }

                if (dayItem.FirstStartTime == -1)
                {
                    dayItem.FirstStartTime = lastStartTime;
                    dayItem.NumOfStartTime++;
                }

                if (zoneItem != null && zoneItem.ZoneNumber < item.ZoneNum)
                {
                    zoneIndex++;
                }

                zoneItem = WeeklyScheduleZones[zoneIndex];

                if (item.Time.HasValue)
                {
                    zoneItem.Days[item.DayNum].Duration += item.Time;
                }
                if (item.Quantity.HasValue)
                {
                    zoneItem.Days[item.DayNum].Quantity += item.Quantity;
                }

            }

            #endregion

            Weekly.Zones = WeeklyScheduleZones.ToArray();

            return Weekly;
        }

        public DailyScheduleView GetDailyScheduleView(DAL.DataAccessLayer.Models.Zone.ZoneList[] ZoneList,
                                                      IrrigationSchedule IrrigationSchedule,
                                                      DAL.DataAccessLayer.Models.Device.DaySettings[] daySettings = null,
                                                      int DayNumber = 0)
        {
            var Daily = new DailyScheduleView();
            Daily.ScheduleType = (ScheduleTypes)IrrigationSchedule.ScheduleType;

            Daily.Day = new ScheduleDayTitle()
            {
                DayNumber = DayNumber
            };

            if (daySettings != null) // when ScheduleType is Weekly
            {
                var Times = new List<TimeValueItem>();
                foreach (var item in daySettings)
                {
                    Times.Add(new TimeValueItem() { Time = item.Time, Allowed = item.IrrigationAllowed });
                }
                Daily.Day.SettingsView = new DaySettingsView() { Times = Times };
            }

            #region GetStartTime

            List<DailyStartTime> DailyStartTimes = new List<DailyStartTime>();

            #endregion

            #region GetZone

            DailyScheduleZone[] DailyScheduleZones = ZoneList.Where(z => z.IsEnabled).Select(s => new DailyScheduleZone()
            {
                ZoneNumber = s.Number,
                Name = s.Name,
                Starts = new List<DailyScheduleZone2Day>()//[IrrigationSchedule.CountStartTime].Select(u => new DailyScheduleZone2Day() { Duration = 0, Quantity = 0 }).ToList() // 
            }).ToArray();

            #endregion

            #region OrderTimes

            int lastTime = -1;
            var indexTime = -1;
            var indexZone = 0;

            foreach (var item in IrrigationSchedule.ScheduleItems)
            {
                if (lastTime != item.StartTime)
                {
                    lastTime = item.StartTime;
                    indexTime++;
                    DailyStartTimes.Add(new DailyStartTime() { Time = item.StartTime });
                    for (int i = 0; i < DailyScheduleZones.Length; i++)
                    {
                        DailyScheduleZones[i].Starts.Add(new DailyScheduleZone2Day() { Duration = 0, Quantity = 0 });
                    }
                    indexZone = 0;
                }

                var startTime = DailyScheduleZones[indexZone].Starts[indexTime];

                startTime.Duration = item.Time.GetValueOrDefault(0);
                startTime.Quantity = item.Quantity.GetValueOrDefault(0);
                indexZone++;
            }

            #endregion

            Daily.Zones = DailyScheduleZones;
            Daily.StartTimes = DailyStartTimes.ToArray();

            return Daily;
        }

        #endregion

        public bool UpdateDeviceScheduleWeekly(string SN, Schedule.WeeklyScheduleView WeeklySchedule)
        {
            bool result = false;
            var IrrigationSchedule_new = new IrrigationSchedule();
            //in weekly save only the days with 1 startTime
            var days = WeeklySchedule.TitleDays.Where(d => d.NumOfStartTime == 1);


            #region Add or update
            var list_ToSave = new List<IrrigationScheduleItem>();
            foreach (var itemDay in days)
            {
                list_ToSave.AddRange(WeeklySchedule.Zones.Select(zone => new IrrigationScheduleItem()
                {
                    ZoneNum = zone.ZoneNumber,
                    DayNum = itemDay.DayNumber,
                    Time = zone.Days[itemDay.DayNumber].Duration,
                    Quantity = zone.Days[itemDay.DayNumber].Quantity,
                    StartTime = itemDay.FirstStartTime
                }));

            }

            result = _AdminRepository.IrrigationSchedule_Items_Update(SN, list_ToSave, (byte)Schedule.BaseDeviceScheduleView.ScheduleTypes.Weekly);

            if (!result)
                return result;

            result = _AdminRepository.ScheduleType_Update(SN, (byte)Schedule.BaseDeviceScheduleView.ScheduleTypes.Weekly);

            return result;

            #endregion


        }

        public Schedule.DailyScheduleView GetDevice_WeeklySchedule_ByDay(string SN, int DayNumber)
        {
            var deviceZones = _AdminRepository.GetDeviceZones(SN).Where(u => u.IsEnabled == true).ToArray();
            return GetDailyScheduleView(deviceZones,
                                        _AdminRepository.IrrigationSchedule_GetByDay(SN, DayNumber, (byte)Schedule.BaseDeviceScheduleView.ScheduleTypes.Weekly),
                                        _AdminRepository.DaySetting_Get(SN).Where(s => s.DayIndex == DayNumber).ToArray(),
                                         DayNumber);
        }

        public bool UpdateDeviceSchedule_ByDay(string SN, Schedule.DailyScheduleView DailySchedule, Schedule.BaseDeviceScheduleView.ScheduleTypes ScheduleType)
        {
            var result = false;

            #region Add or update

            var indexTime = 0;

            var list_ToSave = new List<IrrigationScheduleItem>();
            foreach (var item in DailySchedule.StartTimes)
            {
                list_ToSave.AddRange(DailySchedule.Zones.Select(Zoneitem => new IrrigationScheduleItem()
                {
                    StartTime = item.Time,
                    ZoneNum = Zoneitem.ZoneNumber,
                    Quantity = Zoneitem.Starts[indexTime].Quantity,
                    Time = Zoneitem.Starts[indexTime].Duration,
                    DayNum = DailySchedule.Day.DayNumber
                }));

                indexTime++;
            }

            result = _AdminRepository.IrrigationSchedule_Items_Update(SN, list_ToSave, (byte)ScheduleType);

            if (!result)
                return result;
            #endregion

            result = _AdminRepository.ScheduleType_Update(SN, (byte)ScheduleType);

            return result;
        }

        public Zone.ZoneListView[] GetDeviceZones(string SN)
        {
            var zones = (_AdminRepository.GetDeviceZones(SN)
                .Select(u => new Zone.ZoneListView(u)))
                .ToArray();

            foreach (var z in zones)
            {
                z.ImageURI = this.CurrentSettings.ZonesFileSettings.GetZoneDefaultImage(z.ImageURI, z.ZoneNumber);
            }

            return zones;
        }

        //public bool UpdateDeviceName(string SN, string Name)
        //{
        //    return _AdminRepository.UpdateDeviceName(SN, Name);
        //}

        public bool UpdateDeviceZone(string SN, int ZoneNumber, bool IsEnabled)
        {
            return _AdminRepository.ActiveZone_Update(SN, ZoneNumber, IsEnabled);
        }

        public Settings.DeviceSettingsViewBase GetDeviceSettingsBase(string SN)
        {
            return new Settings.DeviceSettingsViewBase(_AdminRepository.Settings_Get(SN));
        }

        public bool UpdateDeviceSettingsView(string SN, Settings.DeviceSettingsViewBase setting)
        {
            return _AdminRepository.DeviceSettings_Update(SN, new DeviceSettings()
            {
                HoldUntil = setting.HoldUntil,
                UserWeatherSavingAlgorithm = setting.UserWeatherSavingAlgorithm,
                UseSiteSessionSettings = setting.UseSiteSessionSettings,
                HoldType = setting.HoldType
            });
        }
    }
}
