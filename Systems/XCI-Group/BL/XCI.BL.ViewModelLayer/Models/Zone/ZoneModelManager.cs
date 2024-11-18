
using System;
using System.Collections.Generic;
using System.Linq;


using Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Schedule;
using Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Settings;
using Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Zone.Schedule;
using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device;
using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Zone;

using System.Text;
using System.Threading.Tasks;
using ScheduleTypes = Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Schedule.BaseDeviceScheduleView.ScheduleTypes;
using Maba.Connectors.WeatherServices.PETProcessing.AgricultureData;
using Maba.Connectors.WeatherServices;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Zone
{
    public class ZoneModelManager : ViewModelManager.BaseViewModelManager
    {

        private const Double MAXPET = 9.999166667;
        private const Double DAILY_MAXPET = 0.3275;

        #region members

        private DAL.DataAccessLayer.Repositories.Admin.IAdminRepository _AdminRepository = null;

        public delegate void ExceptionDelegate(object sender, UnhandledExceptionEventArgs e);
        public event ExceptionDelegate OnException;

        #endregion

        #region ctor

        public ZoneModelManager(ViewModelLayer.Settings.ViewModelLayerSettings currentSettings)
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

        public ZoneIrrigationSuggestionView GetIrrigationSuggestion(string SN, int ZoneNumber)
        {
            var IrrigationSuggestions = _AdminRepository.IrrigationSuggestions_Get(SN, ZoneNumber);
            if (IrrigationSuggestions == null || IrrigationSuggestions.Number == 0)
            {
                //get new IrrigationSuggestions and update db
                return Algorithms_Advisor(SN, ZoneNumber);
            }

            return new ZoneIrrigationSuggestionView(IrrigationSuggestions, _AdminRepository.ZoneIrrigationAccumulate_Get(SN, ZoneNumber));
        }

        #endregion

        public ZoneIrrigationSuggestionView UpdateScheduleAdvisor(string SN, int ZoneNumber, BL.ViewModelLayer.Models.Zone.AdvisorUpdateSelectedTypeView[] Request, AdvisorAllOptionsView AdvisorView = null)
        {
            //1.Save Categories
            foreach (var item in Request)
            {
                _AdminRepository.Categories_Update(SN, ZoneNumber, new Categories()
                {
                    SubTypeID = item.SubTypeID,
                    CustomValue = item.CustomValue,
                    TypeID = item.TypeID
                });
            }
            //2.Algorithms Advisor -> creat IrrigationSuggestion

            return Algorithms_Advisor(SN, ZoneNumber, AdvisorView);
        }

        public AdvisorAllOptionsView GetScheduleAdvisor(string SN, int ZoneNumber)
        {
            var _AdvisorAllOptionsView = new AdvisorAllOptionsView();
            _AdvisorAllOptionsView.SN = SN;
            _AdvisorAllOptionsView.ZoneNumber = ZoneNumber;
            var Categorys = _AdminRepository.Categories_Get(SN, ZoneNumber);

            #region PlantType

            _AdvisorAllOptionsView.PlantType = new AdvisorTypeView<AdvisorPlantOptionalTypeView>();

            //get custom value , if any
            var Category_p = Categorys.FirstOrDefault(t => t.TypeID == (int)AdvisorTypes.PlantType);

            var DAL_PlantTypes = _AdminRepository.GetPlantTypes();
            _AdvisorAllOptionsView.PlantType.OptionalValues = DAL_PlantTypes
                .Select(u => new AdvisorPlantOptionalTypeView()
                {
                    IsSelected = Category_p != null ? u.ID == Category_p.SubTypeID : u.IsDefault,
                    TypeID = u.ID,
                    TypeTitle = u.TypeTitle,
                    ImageURI = this.CurrentSettings.ZonesFileSettings.GetAdvisorImage(u.ImageLink),
                    CropCoefficient = u.CropCoefficient,
                    Value = Category_p != null ? Category_p.CustomValue.GetValueOrDefault(u.CropCoefficient.GetValueOrDefault(0)) : u.CropCoefficient.GetValueOrDefault(0),
                    IsCustom = u.IsCustom

                })
                .ToArray();

            _AdvisorAllOptionsView.PlantType.AdvisorTypeID = (int)AdvisorTypes.PlantType;
            _AdvisorAllOptionsView.PlantType.TypeTitle = "PlantType";

            #endregion

            #region Slope

            _AdvisorAllOptionsView.SlopeType = new AdvisorTypeView<BaseAdvisorOptionalTypeView>();

            //get custom value , if any
            var Category_sl = Categorys.FirstOrDefault(t => t.TypeID == (int)AdvisorTypes.SlopeType);

            var DAL_SlopeTypes = _AdminRepository.GetSlopeType();
            _AdvisorAllOptionsView.SlopeType.OptionalValues = DAL_SlopeTypes
                .Select(u => new BaseAdvisorOptionalTypeView()
                {
                    IsSelected = Category_sl != null ? u.ID == Category_sl.SubTypeID : u.IsDefault,
                    TypeID = u.ID,
                    TypeTitle = u.TypeTitle,
                    ImageURI = this.CurrentSettings.ZonesFileSettings.GetAdvisorImage(u.ImageLink),
                    // Value 
                    IsCustom = u.IsCustom

                })
                .ToArray();

            _AdvisorAllOptionsView.SlopeType.AdvisorTypeID = (int)AdvisorTypes.SlopeType;
            _AdvisorAllOptionsView.SlopeType.TypeTitle = "SlopeType";


            #endregion

            #region Soil

            _AdvisorAllOptionsView.SoilType = new AdvisorTypeView<BaseAdvisorOptionalTypeView>();

            //get custom value , if any
            var Category_so = Categorys.FirstOrDefault(t => t.TypeID == (int)AdvisorTypes.SoilType);

            var DAL_SoilTypes = _AdminRepository.GetSoilTypes();
            _AdvisorAllOptionsView.SoilType.OptionalValues = DAL_SoilTypes
                .Select(u => new BaseAdvisorOptionalTypeView()
                {
                    IsSelected = Category_so != null ? u.ID == Category_so.SubTypeID : u.IsDefault,
                    TypeID = u.ID,
                    TypeTitle = u.TypeTitle,
                    ImageURI = this.CurrentSettings.ZonesFileSettings.GetAdvisorImage(u.ImageLink),
                    IsCustom = u.IsCustom,
                    //Value = ISCategory ? Category.CustomValue : null,
                })
                .ToArray();

            _AdvisorAllOptionsView.SoilType.AdvisorTypeID = (int)AdvisorTypes.SoilType;
            _AdvisorAllOptionsView.SoilType.TypeTitle = "SoilType";

            #endregion

            #region Sprinkler

            _AdvisorAllOptionsView.SprinklerType = new AdvisorTypeView<AdvisorSprinklerOptionalTypeView>();

            //get custom value , if any
            var Category_sp = Categorys.FirstOrDefault(t => t.TypeID == (int)AdvisorTypes.SprinklerType);

            var DAL_SprinklTypes = _AdminRepository.GetSprinklTypes();
            _AdvisorAllOptionsView.SprinklerType.OptionalValues = DAL_SprinklTypes
                .Select(u => new AdvisorSprinklerOptionalTypeView()
                {
                    IsSelected = Category_p != null ? u.ID == Category_sp.SubTypeID : u.IsDefault,
                    TypeID = u.ID,
                    TypeTitle = u.TypeTitle,
                    ImageURI = this.CurrentSettings.ZonesFileSettings.GetAdvisorImage(u.ImageLink),
                    FlowEstimate = u.FlowEstimate,
                    PrecipRate = u.PrecipRate,
                    RuntimeMultiplier = u.RuntimeMultiplier,
                    Value = Category_p != null ? Category_sp.CustomValue.GetValueOrDefault(u.PrecipRate.GetValueOrDefault(0)) : u.PrecipRate.GetValueOrDefault(0),
                    IsCustom = u.IsCustom
                })
                .ToArray();

            _AdvisorAllOptionsView.SprinklerType.AdvisorTypeID = (int)AdvisorTypes.SprinklerType;
            _AdvisorAllOptionsView.SprinklerType.TypeTitle = "Sprinkler";

            #endregion

            #region SunExposure

            _AdvisorAllOptionsView.SunExposureType = new AdvisorTypeView<AdvisorSunExposureOptionalTypeView>();

            //get custom value , if any
            var Category_su = Categorys.FirstOrDefault(t => t.TypeID == (int)AdvisorTypes.SunExposureType);

            var DAL_SunExposureTypes = _AdminRepository.GetSunExposureTypes();
            _AdvisorAllOptionsView.SunExposureType.OptionalValues = DAL_SunExposureTypes
                .Select(u => new AdvisorSunExposureOptionalTypeView()
                {
                    IsSelected = Category_su != null ? u.ID == Category_su.SubTypeID : u.IsDefault,
                    TypeID = u.ID,
                    TypeTitle = u.TypeTitle,
                    ImageURI = this.CurrentSettings.ZonesFileSettings.GetAdvisorImage(u.ImageLink),
                    SolarAdjustment = u.SolarAdjustment,
                    // Value = ISCategory ? Category.CustomValue : null,
                    IsCustom = u.IsCustom
                })
                .ToArray();

            _AdvisorAllOptionsView.SunExposureType.AdvisorTypeID = (int)AdvisorTypes.SunExposureType;
            _AdvisorAllOptionsView.SunExposureType.TypeTitle = "SunExposureType";

            #endregion

            #region if Categorizes is null Update the Default

            if (Categorys == null || Categorys.Length == 0)
            {
                var _advisorSelectedList = new AdvisorUpdateSelectedTypeView[5];

                //PlantType
                _advisorSelectedList[0] = new AdvisorUpdateSelectedTypeView()
                {
                    TypeID = _AdvisorAllOptionsView.PlantType.AdvisorTypeID,
                    SubTypeID = _AdvisorAllOptionsView.PlantType.OptionalValues.FirstOrDefault(s => s.IsSelected).TypeID,
                };


                //Slope
                _advisorSelectedList[1] = new AdvisorUpdateSelectedTypeView()
                {
                    TypeID = _AdvisorAllOptionsView.SlopeType.AdvisorTypeID,
                    SubTypeID = _AdvisorAllOptionsView.SlopeType.OptionalValues.FirstOrDefault(s => s.IsSelected).TypeID,
                };


                //Soil
                _advisorSelectedList[2] = new AdvisorUpdateSelectedTypeView()
                {
                    TypeID = _AdvisorAllOptionsView.SoilType.AdvisorTypeID,
                    SubTypeID = _AdvisorAllOptionsView.SoilType.OptionalValues.FirstOrDefault(s => s.IsSelected).TypeID,
                };


                //Sprinkler
                _advisorSelectedList[3] = new AdvisorUpdateSelectedTypeView()
                {
                    TypeID = _AdvisorAllOptionsView.SprinklerType.AdvisorTypeID,
                    SubTypeID = _AdvisorAllOptionsView.SprinklerType.OptionalValues.FirstOrDefault(s => s.IsSelected).TypeID,
                };

                //SunExposure
                _advisorSelectedList[4] = new AdvisorUpdateSelectedTypeView()
                {
                    TypeID = _AdvisorAllOptionsView.SunExposureType.AdvisorTypeID,
                    SubTypeID = _AdvisorAllOptionsView.SunExposureType.OptionalValues.FirstOrDefault(s => s.IsSelected).TypeID,
                };

                UpdateScheduleAdvisor(SN, ZoneNumber, _advisorSelectedList, _AdvisorAllOptionsView);
            }

            #endregion

            #region IrrigationSuggestion

            if (_AdvisorAllOptionsView.IrrigationSuggestion == null)
            {
                var IrrigationSuggestions = _AdminRepository.IrrigationSuggestions_Get(SN, ZoneNumber);
                if (IrrigationSuggestions == null || IrrigationSuggestions.Number == 0)
                {
                    // get new IrrigationSuggestions and update db
                    _AdvisorAllOptionsView.IrrigationSuggestion = Algorithms_Advisor(SN, ZoneNumber, _AdvisorAllOptionsView);
                }
                else
                {
                    _AdvisorAllOptionsView.IrrigationSuggestion = new ZoneIrrigationSuggestionView(IrrigationSuggestions, _AdminRepository.ZoneIrrigationAccumulate_Get(SN, ZoneNumber));
                }
            }

            #endregion

            return _AdvisorAllOptionsView;
        }

        public bool UpdateZone(string SN, int ZoneNumber, string name)
        {
            return _AdminRepository.Zone_Name_Update(SN, ZoneNumber, name);
        }

        public Zone.ZoneListView GetZoneInfo(string SN, int ZoneNumber)
        {
            return new Zone.ZoneListView(_AdminRepository.GetZone(SN, ZoneNumber));
        }
        public Zone.ZoneView GetZone(string SN, int ZoneNumber)
        {
            ZoneList zone = _AdminRepository.GetZone(SN, ZoneNumber);
            var _DAL_FlowSensorSettings = _AdminRepository.FlowSensorSettings_Get(SN, ZoneNumber);
            var _DALZoneSettings = _AdminRepository.ZoneSettings_Get(SN, ZoneNumber);

            ZoneListView[] deviceZones = null;

            using (var deviceManager = new Device.DeviceModelManager(this.CurrentSettings))
            {
                deviceZones = deviceManager.GetDeviceZones(SN);
            }

            //var deviceZones=this.zones
            return new ZoneView()
            {
                Name = zone.Name,
                ImageURI = this.CurrentSettings.ZonesFileSettings.GetZoneDefaultImage(zone.ImageURI, zone.Number),
                ZoneNumber = zone.Number,
                SN = SN,
                CategoriesView = this.GetScheduleAdvisor(SN, ZoneNumber),
                DeviceZones = deviceZones,
                FlowSensorSettings = _DAL_FlowSensorSettings == null ? ZoneFlowSensorSettingsView.CreateDefault() : new ZoneFlowSensorSettingsView(_DAL_FlowSensorSettings),
                Settings = _DALZoneSettings == null ? ZoneIrrigationSettingsView.CreateDefault() : new ZoneIrrigationSettingsView(_DALZoneSettings),
                ScheduleView = GetIrrigationSchedule(SN, ZoneNumber)
            };
        }



        public bool Zone_UpdateSettings(string SN, int ZoneNumber, ZoneIrrigationSettingsView Request)
        {
            return _AdminRepository.Zone_UpdateSettings(SN, ZoneNumber,
                new ZoneIrrigationSettings()
                {
                    IrrigationFactor = Request.IrrigationFactor,
                    IsEnabled = Request.IsEnabled,
                    UserWeatherAlgorithm = Request.UserWeatherSavingAlgorithm,
                    WireColor = Request.WireColor
                });
        }

        public bool Zone_UpdateFlowSensorSettings(string SN, int ZoneNumber, ZoneFlowSensorSettingsView Request)
        {
            return _AdminRepository.Zone_FlowSensorSettings_Update(SN, ZoneNumber, new ZoneFlowSensorSettings()
            {
                LastObservedFlow = Request.LastObservedFlow,
                NominalFlow = Request.NominalFlow,
                ThresholdOverFlow = Request.ThresholdOverFlow,
                ThresholdUnderFlow = Request.ThresholdUnderFlow,
                TimeFillDelay = Request.TimeFillDelay
            });
        }



        public ZoneIrrigationScheduleView GetWeeklyScheduleView(IrrigationSchedule Schedule, DaySettings[] DaySettings)
        {
            //make sure it is 7 Days

            var daySettings_new = new DaySettings[7].Select(u => new DaySettings()).ToArray();

            foreach (var item in DaySettings)
            {
                daySettings_new[item.DayIndex] = item;
            }

            var ZoneView = new ZoneIrrigationScheduleView();

            ZoneView.TitleDays = new ScheduleDayView[7];

            for (int i = 0; i < 7; i++)
            {
                ZoneView.TitleDays[i] = new ScheduleDayView() { DayNumber = (byte)(i), IsAllowedDay = daySettings_new[i].IrrigationAllowed };
            }


            //ZoneView.TotalWeeklyDays = Schedule.ScheduleItems
            //                    .Where(d => d.Quantity > 0 || d.StartTime > 0)
            //                    .GroupBy(d => d.DayNum)
            //                    .Count();

            bool[] WeeklyDays = new bool[7];
            ZoneView.ScheduleType = (ScheduleTypes)Schedule.ScheduleType;

            int totalWeeklySeconds = 0;

            #region Bulid Days

            var _rows = new List<ZoneIrrigationScheduleRow>();
            ZoneIrrigationScheduleRow row = null;

            var lastTime = -1;
            foreach (var item in Schedule.ScheduleItems)
            {
                if (lastTime != item.StartTime)
                {
                    lastTime = item.StartTime;
                    row = new ZoneIrrigationScheduleRow()
                    {
                        Time = item.StartTime,
                        Days = Enumerable.Range(0, 7)
                                       .Select(i => new ZoneIrrigationScheduleDay() { Quantity = 0, Duration = 0, Day = i }).ToArray()
                    };

                    _rows.Add(row);
                }
                WeeklyDays[item.DayNum] = item.Quantity.GetValueOrDefault(0) != 0 ? true : WeeklyDays[item.DayNum];
                row.Days[item.DayNum].Duration = item.Time.GetValueOrDefault(0);
                row.Days[item.DayNum].Quantity = item.Quantity.GetValueOrDefault(0);

                totalWeeklySeconds += item.Quantity.GetValueOrDefault(0);
            }


            #endregion



            #region Max && Total

            ZoneView.TotalWeeklyMinutes = totalWeeklySeconds / 60;
            ZoneView.TotalWeeklyDays = WeeklyDays.Count(s => s);
            ZoneView.Rows = _rows.ToArray();
            #endregion

            return ZoneView;

        }

        public Schedule.BaseZoneScheduleView GetIrrigationSchedule(string SN, int ZoneNumber, Byte? ScheduleType = null)
        {
            var zoneSetting = _AdminRepository.ZoneSettings_Get(SN, ZoneNumber);

            Schedule.BaseZoneScheduleView schedule = null;

            var Schedule = _AdminRepository.IrrigationSchedule_GetByZone(SN, ZoneNumber, ScheduleType);

            switch ((ScheduleTypes)Schedule.ScheduleType)
            {
                case ScheduleTypes.Weekly:
                    schedule = Zone.Schedule.BaseZoneScheduleView.GetWeeklyScheduleView(Schedule, _AdminRepository.DaySetting_Get(SN));
                    break;
                case ScheduleTypes.Odd:
                case ScheduleTypes.Even:
                    schedule = Zone.Schedule.BaseZoneScheduleView.GetDailyScheduleView(Schedule.ScheduleItems, (ScheduleTypes)Schedule.ScheduleType);
                    break;
                default:
                    return null;

            }

            schedule.SN = SN;
            schedule.ZoneNumber = ZoneNumber;
            if (zoneSetting != null)
            {
                schedule.MaxSoakTime = zoneSetting.MaxSoakTime;
                schedule.MaxCycleTime = zoneSetting.MaxCycleTime;

            }
            return schedule;
        }

        public bool UpdateSchedule_OddEven_Zone(string SN, int ZoneNumber, Schedule.ZoneIrrigationScheduleDailyView DailySchedule,
                    BL.ViewModelLayer.Models.Device.Schedule.BaseDeviceScheduleView.ScheduleTypes ScheduleType)
        {
            var result = false;
            result = Zone_UpdateSoakSettings(SN, ZoneNumber, DailySchedule.MaxCycleTime, DailySchedule.MaxSoakTime);

            if (!result)
                return result;

            result = _AdminRepository.IrrigationSchedule_Items_Update(SN, DailySchedule.StartTimes.Select(item => new IrrigationScheduleItem()
            {
                StartTime = item.Time,
                ZoneNum = DailySchedule.ZoneNumber,
                Quantity = item.Quantity,
                Time = item.Duration,
                DayNum = 0
            }).ToList(), (byte)ScheduleType);
            if (!result)
                return result;

            return result;
        }

        public bool Zone_UpdateSoakSettings(string SN, int ZoneNumber, int? MaxCycleTime, int? MaxSoakTime)
        {
            return _AdminRepository.Zone_SoakSettings_Update(SN, ZoneNumber, MaxCycleTime, MaxSoakTime);
        }

        public bool UpdateSchedule_Weekly_Zone(string SN, int ZoneNumber, Schedule.ZoneIrrigationScheduleView item)
        {
            var result = false;
            result = Zone_UpdateSoakSettings(SN, ZoneNumber, item.MaxCycleTime, item.MaxSoakTime);
            if (!result)
                return result;

            var list = new List<DAL.DataAccessLayer.Models.Device.IrrigationScheduleItem>();

            foreach (var itemRow in item.Rows)
            {
                list.AddRange(itemRow.Days.Select(itemPerDay => new DAL.DataAccessLayer.Models.Device.IrrigationScheduleItem()
                {
                    DayNum = itemPerDay.Day,
                    Quantity = itemPerDay.Quantity,
                    Time = itemPerDay.Duration,
                    ZoneNum = ZoneNumber,
                    StartTime = itemRow.Time

                }).ToList());
            }

            result = _AdminRepository.IrrigationSchedule_Items_Update(SN, list, (byte)ScheduleTypes.Weekly);
            return result;
        }

        private ZoneIrrigationSuggestionView Algorithms_Advisor(string SN, int ZoneNumber, AdvisorAllOptionsView AdvisorView = null)
        {
            if (AdvisorView == null)
            {
                AdvisorView = GetScheduleAdvisor(SN, ZoneNumber);
            }
            var Sprinkler = AdvisorView.SprinklerType.OptionalValues.FirstOrDefault(t => t.IsSelected);
            Double? precipRate = (Double?)Sprinkler.Value;

            Double? runTimeMultiplier = (Double?)Sprinkler.RuntimeMultiplier;
            if (!precipRate.HasValue)
            {
                precipRate = 1;
                runTimeMultiplier = 1;
            }

            Double? kcAdjust = (Double?)AdvisorView.PlantType.OptionalValues.FirstOrDefault(t => t.IsSelected).CropCoefficient;
            if (!kcAdjust.HasValue)
            {
                kcAdjust = 0.8;
            }


            Double? slopeTypeID = (Double?)AdvisorView.SlopeType.OptionalValues.FirstOrDefault(t => t.IsSelected).TypeID;
            if (!slopeTypeID.HasValue)
            {
                slopeTypeID = 3;
            }

            Double? solarAdjust = (Double?)AdvisorView.SunExposureType.OptionalValues.FirstOrDefault(t => t.IsSelected).SolarAdjustment;
            if (!solarAdjust.HasValue)
            {
                solarAdjust = 1.10;
            }


            Double? soilTypeID = (Double?)AdvisorView.SoilType.OptionalValues.FirstOrDefault(t => t.IsSelected).TypeID;
            if (!soilTypeID.HasValue)
            {
                soilTypeID = 3;
            }

            #region Get PET Values

            //Get PET values in the site
            var d = _AdminRepository.GetDevice(SN);
            //get device Location
            AgricultureRecord pet = null;
            if (!string.IsNullOrEmpty(d.Map_Latitude) && !string.IsNullOrEmpty(d.Map_Latitude))
            {
                using (var agricultureRepository = this.CurrentSettings.AgricultureRepositoryFunc())
                {
                    var location = new Location() { lat = decimal.Parse(d.Map_Latitude), lon = decimal.Parse(d.Map_Longitude) };
                    pet = agricultureRepository.GetPETRecord(location, 2);
                }
            }

            /////******defult value***************
            //ave of ave max total pet = 4.76729324
            //max of ave max total pet = 9.999166667

            //ave of ave max daily pet = 0.156288206
            //max of ave max daily pet = 0.3275

            Double maxPET = MAXPET;
            Double dailyMaxPET = DAILY_MAXPET;

            if (pet != null)
            {
                maxPET = (Double)(pet.Total_Summary_Temp.MAX);
                dailyMaxPET = (Double)(pet.Daily_Summary.MAX);
            }

            #endregion


            ///############################################
            double runtimeOverrideAdjust = 1;

            var dailyRunTime = (((((maxPET * kcAdjust * runTimeMultiplier * (Double)60) / precipRate) / (Double)31) * solarAdjust) * runtimeOverrideAdjust);
            var runTimePerDay = Convert.ToInt32(dailyRunTime);

            //Number of Cycles for the valve
            int PR1 = (Convert.ToDouble(precipRate) > .8) ? 1 : 0;
            int PR2 = (Convert.ToDouble(precipRate) > 1.5) ? 1 : 0;
            int Slope1 = (slopeTypeID != 3) ? 1 : 0; // (slopeTypeID > 0) ? 1 : 0;   0 ->3
            int Slope2 = (slopeTypeID == 2) ? 1 : 0;// (slopeTypeID > 1) ? 1 : 0;
            int Soil1 = (soilTypeID == 2) ? 1 : 0; // (soilTypeID > 1) ? 1 : 0
            int Soil2 = (Soil1 > 0) ? 1 : 0;
            int i = (PR1 + PR2 + Slope1 + Slope2 + Soil1 + Soil2);
            var cyclesPerDay = ((i + 1) > 4) ? 4 : i + 1;

            //Runtime per cycle
            //////Suggestion_MaximumCycleMinutes
            var runTimePerCycle = Convert.ToInt32(runTimePerDay / cyclesPerDay);

            //Suggestion_SoakTimeMinutes
            //Amount of soak time between cycles
            var minSoakTime = (cyclesPerDay < 2) ? 0 : cyclesPerDay * 10;

            //Number of Irrigations per Month
            double x = 0.33 / (Convert.ToDouble(dailyMaxPET) * Convert.ToDouble(kcAdjust));
            var events = (x > 12) ? 2 : Convert.ToInt32(30 / x);
            var wateringsPerMonth = (soilTypeID != 2) ? Convert.ToInt32(((Convert.ToDouble(events) / 4) + 1) * 4) : events;
            //Certain situations of Sandy Soil Type (ID=1) and PETs approaching 12 resulted in Irrigations/Month
            // > number of days in the month. This step added to trap this uncommon (but possible) scenario
            wateringsPerMonth = (wateringsPerMonth > 30) ? 30 : wateringsPerMonth;

            //Number of Irrigations per week
            //Suggestion_TotalWeeklyDays
            var wateringsPerWeek = Convert.ToInt32(Convert.ToDouble(wateringsPerMonth) / 4.1);


            //Suggestion_TotalWeeklyMinutes
            var weeklyTotalMinutes = wateringsPerWeek * runTimePerDay;




            var _IrrigationSuggestion =
            new ZoneIrrigationSuggestionView()
            {
                Suggestion_MaximumCycleMinutes = runTimePerCycle,
                Suggestion_TotalWeeklyDays = wateringsPerWeek,
                Suggestion_TotalWeeklyMinutes = weeklyTotalMinutes,
                Suggestion_SoakTimeMinutes = minSoakTime,
                Suggestion_RunTimeDaily = runTimePerDay,
                Suggestion_TotalMonthMinutes = wateringsPerMonth,
                Number = ZoneNumber
            };

            _AdminRepository.IrrigationSuggestion_Update(SN, new ZoneIrrigationSuggestion()
            {

                Suggestion_MaximumCycleMinutes = _IrrigationSuggestion.Suggestion_MaximumCycleMinutes,
                Suggestion_SoakTimeMinutes = _IrrigationSuggestion.Suggestion_SoakTimeMinutes,
                Suggestion_TotalWeeklyDays = _IrrigationSuggestion.Suggestion_TotalWeeklyDays,
                Suggestion_TotalWeeklyMinutes = _IrrigationSuggestion.Suggestion_TotalWeeklyMinutes,
                Suggestion_RunTimeDaily = _IrrigationSuggestion.Suggestion_RunTimeDaily,
                Suggestion_TotalMonthMinutes = _IrrigationSuggestion.Suggestion_TotalMonthMinutes,
                Number = ZoneNumber
            }
               );

            var zoneSetting = _AdminRepository.ZoneIrrigationAccumulate_Get(SN, ZoneNumber);
            if (zoneSetting != null)
            {
                _IrrigationSuggestion.Current_TotalWeeklyMinutes = zoneSetting.Current_TotalWeeklyMinutes;
                _IrrigationSuggestion.Current_WateringDays = zoneSetting.Current_WateringDays;
                _IrrigationSuggestion.MaxCycleTime = zoneSetting.MaxCycleTime;
                _IrrigationSuggestion.MaxSoakTime = zoneSetting.MaxSoakTime;
            }
            return _IrrigationSuggestion;

        }


        public bool AcceptSuggestion(string SN, int ZoneNumber)
        {
            //3.AcceptSuggestion -> 3.1 get IrrigationSuggestion 
            //                      3.2 GetIrrigationSchedule By type in the device 
            //                      3.3 Calculation of irrigation by IrrigationSuggestion  over Scheduletype
            //                      3.4 Save new IrrigationSchedule in db (delete the old in this zone in this type)
            //                      3.5 Save SoakTime and CycleTime
            //                      3.6 Update Zone CurrentValues
            //                      3.7 set AcceptSuggestion to true in db

            //3.1 get IrrigationSuggestion 
            var IrrigationSuggestion = _AdminRepository.IrrigationSuggestions_Get(SN, ZoneNumber);


            //3.2 get GetIrrigationSchedule By type in the device
            var ScheduleType = _AdminRepository.ScheduleType_Get(SN);
            var IrrigationSchedule = _AdminRepository.IrrigationSchedule_Get(SN, ScheduleType);

            var ScheduleItems = IrrigationSchedule.ScheduleItems;


            //3.3
            #region Calculation of irrigation by IrrigationSuggestion


            var list_toSave = new List<IrrigationScheduleItem>();

            #region calcu in Weekly

            if ((ScheduleTypes)ScheduleType == ScheduleTypes.Weekly)
            {
                var SuccessDay = 0;
                var DaySettings_db = _AdminRepository.DaySetting_Get(SN);
                var TotalWeeklyMinutes = IrrigationSuggestion.Suggestion_TotalWeeklyMinutes;
                var TotalWeeklyDays = IrrigationSuggestion.Suggestion_TotalWeeklyDays;
                var RunTimeDaily = TotalWeeklyMinutes / TotalWeeklyDays;

                #region Ordering all ZoneStratTime ,Group IrrigationSchedule

                DaySettingsView[] DaySettings = GetGroupDay(DaySettings_db);
                DailyScheduleGorupView[] AllIrrigationSchedule = new DailyScheduleGorupView[7];
                List<Tuple<DaySettingsView, DailyScheduleGorupView>> DescriptionDay = new List<Tuple<DaySettingsView, DailyScheduleGorupView>>();

                var indexDay = -1;
                var indexStartTime = -1;
                ScheduleTime ScheduleTime = null;
                var inZoneItem = false;
                foreach (var item in ScheduleItems)
                {
                    if (item.ZoneNum == ZoneNumber)
                    {
                        inZoneItem = true;
                    }

                    if (indexDay == -1 ||
                        indexDay != item.DayNum
                        || indexStartTime != item.StartTime)
                    {
                        ScheduleTime = new ScheduleTime() { StartTime = item.StartTime, Duration = 0 };
                        indexStartTime = item.StartTime;
                        indexDay = item.DayNum;
                        if (AllIrrigationSchedule[item.DayNum] == null)
                        {
                            AllIrrigationSchedule[item.DayNum] = new DailyScheduleGorupView() { DayIndex = item.DayNum };
                            DescriptionDay.Add(new Tuple<DaySettingsView, DailyScheduleGorupView>(DaySettings[item.DayNum], AllIrrigationSchedule[item.DayNum]));

                            list_toSave.Add(new IrrigationScheduleItem() // // this day is for delete this day in the transaction -sp
                            {
                                DayNum = item.DayNum,
                                ZoneNum = ZoneNumber,
                                StartTime = -1,
                                Time = -1
                            });
                        }
                        if (AllIrrigationSchedule[item.DayNum].ScheduleStartTime == null)
                        {
                            AllIrrigationSchedule[item.DayNum].ScheduleStartTime = new List<ScheduleTime>() { ScheduleTime };
                        }
                        else
                        {
                            var listTime = AllIrrigationSchedule[item.DayNum].ScheduleStartTime;
                            if (inZoneItem && listTime[0].ZonePriority)
                            {
                                ScheduleTime.ZonePriority = true;
                                listTime.Insert(0, ScheduleTime);
                            }
                            else
                            {
                                AllIrrigationSchedule[item.DayNum].ScheduleStartTime.Add(ScheduleTime);
                            }
                        }
                        inZoneItem = false;
                    }

                    if (item.ZoneNum != ZoneNumber)
                    {
                        ScheduleTime.Duration += item.Time;
                    }
                }

                #endregion

                for (int i = 0; i < 2; i++) //i=0 for allow days,and i=1 for not allow days
                {
                    foreach (var item in MixIndex(DaySettings, a => a.IsIrrigationAllowed == (i == 0)))
                    {

                        var day = DescriptionDay[item.DayIndex];
                        var totalRunTime = 0;
                        var isAllow = false;
                        var minTime = 21600; //6:00 am;
                        var maxTime = 0;
                        foreach (var StartTime in day.Item2.ScheduleStartTime)
                        {
                            totalRunTime = StartTime.StartTime + StartTime.Duration.GetValueOrDefault(0) + RunTimeDaily;
                            if (totalRunTime > 86399)///23:59:59
                            {
                                continue;
                            }
                            isAllow = InAllowBlock(DescriptionDay[item.DayIndex].Item1, totalRunTime);

                            if (isAllow)
                            {
                                SuccessDay++;

                                list_toSave.Add(new IrrigationScheduleItem()
                                {
                                    DayNum = item.DayIndex,
                                    StartTime = StartTime.StartTime,
                                    Time = RunTimeDaily * 60,
                                    ZoneNum = ZoneNumber
                                });

                                break;
                            }

                            minTime = Math.Min(minTime, totalRunTime);
                            maxTime = Math.Max(maxTime, totalRunTime);
                        }


                        if (!isAllow && day.Item2.ScheduleStartTime.Count < 4) //good start time  not found 
                        {

                            //try min time
                            totalRunTime = minTime + RunTimeDaily - 2;
                            isAllow = InAllowBlock(DescriptionDay[item.DayIndex].Item1, totalRunTime);

                            if (isAllow)
                            {
                                SuccessDay++;

                                list_toSave.Add(new IrrigationScheduleItem()
                                {
                                    DayNum = item.DayIndex,
                                    StartTime = minTime,
                                    Time = RunTimeDaily * 60,
                                    ZoneNum = ZoneNumber
                                });

                                break;
                            }

                            //try max time 


                            totalRunTime = maxTime + RunTimeDaily + 2;
                            if (totalRunTime < 86399)
                            {
                                isAllow = InAllowBlock(DescriptionDay[item.DayIndex].Item1, totalRunTime);

                                if (isAllow)
                                {
                                    SuccessDay++;

                                    list_toSave.Add(new IrrigationScheduleItem()
                                    {
                                        DayNum = item.DayIndex,
                                        StartTime = minTime,
                                        Time = RunTimeDaily * 60,
                                        ZoneNum = ZoneNumber
                                    });

                                    break;
                                }
                            }


                            //try ave

                            totalRunTime = (maxTime + minTime) / 2 - 2 + RunTimeDaily;

                            if (totalRunTime < 86399)
                            {
                                isAllow = InAllowBlock(DescriptionDay[item.DayIndex].Item1, totalRunTime);

                                if (isAllow)
                                {
                                    SuccessDay++;

                                    list_toSave.Add(new IrrigationScheduleItem()
                                    {
                                        DayNum = item.DayIndex,
                                        StartTime = minTime,
                                        Time = RunTimeDaily * 60,
                                        ZoneNum = ZoneNumber
                                    });

                                    break;
                                }
                            }



                        }


                        if (SuccessDay >= TotalWeeklyDays)
                            break;
                    }

                    if (SuccessDay >= TotalWeeklyDays)
                        break;

                }

            }
            #endregion

            #region caluc odd even

            if ((ScheduleTypes)ScheduleType == ScheduleTypes.Even || (ScheduleTypes)ScheduleType == ScheduleTypes.Odd)
            {
                var fristStartTime = -1;
                if (ScheduleItems != null && ScheduleItems.Count > 0)
                {
                    var item = ScheduleItems.FirstOrDefault(d => d.ZoneNum == ZoneNumber);
                    if (item != null)
                    {
                        fristStartTime = item.StartTime;
                    }
                    else
                    {
                        item = ScheduleItems.FirstOrDefault();
                        fristStartTime = item.StartTime;
                    }
                }

                if (fristStartTime == -1)
                {
                    fristStartTime = 21600; //6:00 am
                }

                list_toSave.Add(new IrrigationScheduleItem()
                {
                    DayNum = 0,
                    StartTime = fristStartTime,
                    Time = IrrigationSuggestion.Suggestion_TotalMonthMinutes / 15,
                    ZoneNum = ZoneNumber
                });
            }

            #endregion

            #endregion

            var result = false;
            //3.4 Save new IrrigationSchedule in db (delete the old in this zone and this type)

            result = _AdminRepository.IrrigationSchedule_Items_Update(SN, list_toSave, ScheduleType);

            if (!result)
                return result;

            //3.5 Save SoakTime and CycleTime

            result = _AdminRepository.Zone_SoakSettings_Update(SN, ZoneNumber, IrrigationSuggestion.Suggestion_MaximumCycleMinutes, IrrigationSuggestion.Suggestion_SoakTimeMinutes);


            if (!result)
                return result;

            //3.7 set AcceptSuggestion to true in db

            result = _AdminRepository.IrrigationSuggestion_Accept(SN, ZoneNumber);

            return result;
        }


        public bool InAllowBlock(DaySettingsView day, int StartTime)
        {
            var result = true;

            foreach (var item in day.Times)
            {
                if (item.Time < StartTime)
                {
                    result = item.Allowed;
                }
                else
                {
                    return result;
                }
            }
            return result;

        }
        private IEnumerable<DaySettingsView> MixIndex(DaySettingsView[] list, Func<DaySettingsView, bool> predict)
        {
            for (int i = 0; i < 2; i++)
            {
                for (int j = 0; j < list.Length; j++)
                {
                    if (j % 2 - i == 0)
                    {
                        if (predict(list[j]))
                        {
                            yield return list[j];
                        }
                    }
                }
            }
        }

        private DaySettingsView[] GetGroupDay(DaySettings[] daySettings_db)
        {
            var days = new DaySettingsView[7];

            for (int i = 0; i < 7; i++)
            {
                days[i] = new DaySettingsView() { DayIndex = i, Times = new List<TimeValueItem>() };
            }

            foreach (var item in daySettings_db)
            {
                var item_view = days[item.DayIndex];
                if (item_view == null)
                {
                    item_view = days[item.DayIndex] = new DaySettingsView() { DayIndex = item.DayIndex, Times = new List<TimeValueItem>() };
                }

                item_view.Times.Add(new TimeValueItem() { Allowed = item.IrrigationAllowed, Time = item.Time });
            }

            return days;
        }

        public bool Zone_UpdateImage(string SN, int ZoneNumber, string Body)
        {
            return _AdminRepository.Zone_Image_Update(SN, ZoneNumber, Body);
        }
    }
}
