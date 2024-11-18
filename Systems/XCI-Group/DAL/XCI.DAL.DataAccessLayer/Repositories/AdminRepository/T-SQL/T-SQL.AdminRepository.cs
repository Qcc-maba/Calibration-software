using Maba.DAL.BaseDAL;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.Common;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device;
using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Zone;
using System.Data.SqlClient;
using Microsoft.SqlServer.Server;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Repositories.Admin
{
    public class TSQLAdminRepository : BaseConnector, IAdminRepository
    {
        #region CONSTANTS

        public const string DEFAULT_STRING_CONNECTION = "XCI-Group_AdminDB";

        #endregion

        #region ctor

        public TSQLAdminRepository()
            : base(DEFAULT_STRING_CONNECTION)
        {

        }

        public TSQLAdminRepository(string providerName, string stringConnection)
            : base(providerName, stringConnection)
        {

        }
        public TSQLAdminRepository(string stringConnectionSectionName)
            : base(stringConnectionSectionName)
        {

        }

        public TSQLAdminRepository(Connection connection)
            : base(connection)
        {

        }

        #endregion

        #region privet methods
        private static IEnumerable<SqlDataRecord> CreateSqlMetaDataItem(List<Models.Device.TimeValueItem> items)
        {
            SqlMetaData[] metaData = new SqlMetaData[2];
            metaData[0] = new SqlMetaData("Allow", SqlDbType.Bit);
            metaData[1] = new SqlMetaData("Time", SqlDbType.Int);

            return items
                .Select(r =>
                {
                    var record = new SqlDataRecord(metaData);
                    record.SetBoolean(0, r.Allowed);
                    record.SetInt32(1, r.Time);
                    return record;
                });
        }
        private static IEnumerable<SqlDataRecord> CreateSqlMetaDataItem(List<Models.Device.IrrigationScheduleItem> items)
        {
            SqlMetaData[] metaData = new SqlMetaData[5];
            metaData[0] = new SqlMetaData("Quantity", SqlDbType.Int);
            metaData[1] = new SqlMetaData("StartTime", SqlDbType.Int);
            metaData[2] = new SqlMetaData("Time", SqlDbType.Int);
            metaData[3] = new SqlMetaData("ZoneNum", SqlDbType.Int);
            metaData[4] = new SqlMetaData("DayNum", SqlDbType.Int);

            return items
                .Select(r =>
                {
                    var record = new SqlDataRecord(metaData);
                    record.SetInt32(0, r.Quantity.GetValueOrDefault(0));
                    record.SetInt32(1, r.StartTime);
                    record.SetInt32(2, r.Time.GetValueOrDefault(0));
                    record.SetInt32(3, r.ZoneNum);
                    record.SetInt32(4, r.DayNum);
                    return record;
                });
        }
        #endregion 

        #region public methods

        public bool Test()
        {
            bool result;
            int rowAffected = 0;
            var result64 = Connector.GetProcedureResultInt64("Test", new IDataParameter[] {
                                                                      Connector.CreateParameter("Number",1)
                                                                    },
                                                                    out rowAffected, out result);

            return result64 > 0 && result;
        }

        #region Setting

        #region AlertSettings
        public AlertsSetting[] AlertDeviceSettings_Get(string SN)
        {
            return Connector.GetEntities<Models.Device.AlertsSetting>(this.Connector.CreateProcedureEnumerator("Config.AlertDeviceSettings_Get",
                                                                     new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN)
                                                                    })).ToArray();
        }

        public bool AlertSettings_Update(string SN, AlertsSetting alertsSetting)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("config.AlertSettings_Update",
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("SN",SN),
                                                                        Connector.CreateParameter("IsEnable",alertsSetting.IsEnable),
                                                                        Connector.CreateParameter("SendEmail",alertsSetting.SendEmail),
                                                                        Connector.CreateParameter("SendSMS",alertsSetting.SendSMS),
                                                                        Connector.CreateParameter("AlertCode",alertsSetting.AlertCode)
                                                                        }
                                                                       ,
                                                                        out rowsAffected,
                                                                        out Result);

            return Result;
        }

        #endregion

        #region DeviceSettings
        public Models.Device.DeviceSettings Settings_Get(string SN)
        {
            return Connector.GetEntity<Models.Device.DeviceSettings>(this.Connector.CreateProcedureEnumerator("Config.DeviceSettings_Get",
                                                                     new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN)
                                                                    }));
        }
        public bool DeviceSettings_Update(string SN, Models.Device.DeviceSettings deviceSettings)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("config.DeviceSettings_Update",
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("SN",SN),
                                                                        Connector.CreateParameter("HoldUntil",deviceSettings.HoldUntil),
                                                                        Connector.CreateParameter("UserWeatherSavingAlgorithm",deviceSettings.UserWeatherSavingAlgorithm),
                                                                        Connector.CreateParameter("UseSiteSessionSettings",deviceSettings.UseSiteSessionSettings),
                                                                        Connector.CreateParameter("HoldType",deviceSettings.HoldType)
                                                                        }
                                                                       ,
                                                                        out rowsAffected,
                                                                        out Result);

            return Result;
        }

        #endregion

        #region DaySetting

        public Models.Device.DaySettings[] DaySetting_Get(string SN)
        {
            return Connector.GetEntities<Models.Device.DaySettings>(this.Connector.CreateProcedureEnumerator("Config.DaySetting_Get",
                                                                     new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN)
                                                                    })).ToArray();
        }

        public bool DaySettings_Update(string SN, DaySettings daySettings, List<TimeValueItem> items)
        {
            var Result = false;
            int rowsAffected = 0;
            var Parameter = Connector.CreateParameter("Items", CreateSqlMetaDataItem(items)) as SqlParameter;
            Parameter.SqlDbType = SqlDbType.Structured;
            Parameter.TypeName = "config.TimeValue";
            Connector.GetProcedureResultInt32("config.DaySettings_Update",
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("SN",SN),
                                                                        Connector.CreateParameter("DayIndex",daySettings.DayIndex),
                                                                        Connector.CreateParameter("MaxDailyCycles",daySettings.MaxDailyCycles),
                                                                        Connector.CreateParameter("Name",daySettings.Name),
                                                                        Connector.CreateParameter("MaxDailyIrrigrationSeconds",daySettings.MaxDailyIrrigrationSeconds),
                                                                        Parameter
                                                                        },
                                                                        out rowsAffected,
                                                                        out Result);
            return Result;
        }

        #endregion

        #region IrrigatingSettings

        public Models.Device.IrrigatingSettings IrrigatingSettings_Get(string SN)
        {
            return Connector.GetEntity<Models.Device.IrrigatingSettings>(this.Connector.CreateProcedureEnumerator("Config.IrrigatingSettings_Get",
                                                                    new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN)
                                                                    }));
        }

        public bool IrrigatingSettings_Update(string SN, Models.Device.IrrigatingSettings irrigatingSettings)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("config.IrrigatingSettings_Update",
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("SN",SN),
                                                                        Connector.CreateParameter("IrrigationFactor",irrigatingSettings.IrrigationFactor),
                                                                        Connector.CreateParameter("ZoneCloseDelay",irrigatingSettings.ZoneCloseDelay),
                                                                        Connector.CreateParameter("ZoneOpenDelay",irrigatingSettings.ZoneOpenDelay),
                                                                        Connector.CreateParameter("ZonesOverlapTime",irrigatingSettings.ZonesOverlapTime),
                                                                        Connector.CreateParameter("MasterCloseSequence",irrigatingSettings.MasterCloseSequence),
                                                                        Connector.CreateParameter("MasterOpenSequence",irrigatingSettings.MasterOpenSequence)
                                                                        }
                                                                       ,
                                                                        out rowsAffected,
                                                                        out Result);

            return Result;
        }


        #endregion

        #region DisplaySettings
        public Models.Device.DisplaySettings DisplaySettings_Get(string SN)
        {
            return Connector.GetEntity<Models.Device.DisplaySettings>(this.Connector.CreateProcedureEnumerator("Config.DisplaySettings_Get",
                                                                    new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN)
                                                                    }));
        }

        public bool DisplaySettings_Update(string SN, Models.Device.DisplaySettings displaySettings)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("config.DisplaySettings_Update",
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("SN",SN),
                                                                        Connector.CreateParameter("DisplayCharset",displaySettings.DisplayCharset),
                                                                        Connector.CreateParameter("TemperatureType",displaySettings.TemperatureType),
                                                                        Connector.CreateParameter("ClockType",displaySettings.ClockType)
                                                                        }
                                                                       ,
                                                                        out rowsAffected,
                                                                        out Result);

            return Result;
        }


        #endregion

        #region RainSensorSettings

        public Models.Device.RainSensorSettings RainSensorSettings_Get(string SN)
        {
            return Connector.GetEntity<Models.Device.RainSensorSettings>(this.Connector.CreateProcedureEnumerator("Config.RainSensorSettings_Get",
                                                                    new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN)
                                                                    }));
        }

        public bool RainSensorSettings_Update(string SN, Models.Device.RainSensorSettings rainSensorSettings)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("config.RainSensorSettings_Update",
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("SN",SN),
                                                                        Connector.CreateParameter("IsEnabled",rainSensorSettings.IsEnabled),
                                                                        Connector.CreateParameter("RainOffMinDuration",rainSensorSettings.RainOffMinDuration),
                                                                        Connector.CreateParameter("RainStabilitySecTime",rainSensorSettings.RainStabilitySecTime),
                                                                        Connector.CreateParameter("SensorInputNumber",rainSensorSettings.SensorInputNumber),
                                                                        Connector.CreateParameter("SensorType",rainSensorSettings.SensorType)
                                                                        }
                                                                       ,
                                                                        out rowsAffected,
                                                                        out Result);

            return Result;
        }

        #endregion

        #region FlowSensorSettings

        public Models.Device.FlowSensorSettings FlowSensorSettings_Get(string SN)
        {
            return Connector.GetEntity<Models.Device.FlowSensorSettings>(this.Connector.CreateProcedureEnumerator("Config.FlowSensorSettings_Get",
                                                                    new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN)
                                                                    }));
        }

        public bool FlowSensorSettings_Update(string SN, Models.Device.FlowSensorSettings flowSensorSettings)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("config.FlowSensorSettings_Update",
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("SN",SN),
                                                                        Connector.CreateParameter("IsEnabled",flowSensorSettings.IsEnabled),
                                                                        Connector.CreateParameter("Pulse_PulseSize",flowSensorSettings.Pulse_PulseSize),
                                                                        Connector.CreateParameter("Pulse_PulseType",flowSensorSettings.Pulse_PulseType),
                                                                        Connector.CreateParameter("SensorInputNumber",flowSensorSettings.SensorInputNumber),
                                                                        Connector.CreateParameter("SensorType",flowSensorSettings.SensorType),
                                                                        Connector.CreateParameter("DI_KValue",flowSensorSettings.DI_KValue),
                                                                        Connector.CreateParameter("DI_OffsetValue",flowSensorSettings.DI_OffsetValue)
                                                                        }
                                                                       ,
                                                                        out rowsAffected,
                                                                        out Result);

            return Result;
        }

        #endregion


        #region AlertThresholdSettings
        public bool AlertThresholdSettings_Update(string SN, Models.Device.AlertThresholdSettings Settings)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("config.AlertThresholdSettings_Update",
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("SN",SN),
                                                                        Connector.CreateParameter("OverCurrentThreshold",Settings.OverCurrentThreshold),
                                                                        Connector.CreateParameter("UnderCurrentThreshold",Settings.UnderCurrentThreshold),
                                                                        Connector.CreateParameter("IsAlertsEnabled",Settings.IsAlertsEnabled)

                                                                        }
                                                                       ,
                                                                        out rowsAffected,
                                                                        out Result);

            return Result;
        }



        public Models.Device.AlertThresholdSettings AlertThresholdSettings_Get(string SN)
        {
            return Connector.GetEntity<Models.Device.AlertThresholdSettings>(this.Connector.CreateProcedureEnumerator("Config.AlertThresholdSettings_Get",
                                                                    new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN)
                                                                    }));
        }

        #endregion

        #endregion

        #region Schedule




        public byte ScheduleType_Get(string SN)
        {
            bool Result = false;
            int rowsAffected = 0;
            byte? ScheduleType = null;
            DbParameter Parameter_ScheduleTypeID = null;
            Parameter_ScheduleTypeID = Connector.CreateNullParameter("@ScheduleTypeID", typeof(byte));
            Parameter_ScheduleTypeID.Direction = ParameterDirection.Output;

            Connector.GetProcedureResultInt32("config.IrrigationScheduleType_Get", new IDataParameter[] {
                                                                        Connector.CreateParameter("SN",SN),
                                                                       Parameter_ScheduleTypeID
                                                                    }, out rowsAffected, out Result);

            if (Parameter_ScheduleTypeID.Value.GetType() == typeof(byte))
            {
                ScheduleType = (byte)Parameter_ScheduleTypeID.Value;
                return ScheduleType.Value;
            }
            else
                return 0;//not found

        }


        public bool ScheduleType_Update(string SN, byte ScheduleType)
        {
            bool Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("config.IrrigationScheduleType_Update", new IDataParameter[] {
                                                                        Connector.CreateParameter("SN",SN),
                                                                        Connector.CreateParameter("ScheduleType",ScheduleType)
                                                                    }, out rowsAffected, out Result);
            return Result;
        }

        public Models.Device.IrrigationSchedule IrrigationSchedule_Get_OverStartTime(string SN, byte? ScheduleType)
        {
            DbParameter Parameter_ScheduleTypeID = null;

            if (ScheduleType.HasValue)
            {
                Parameter_ScheduleTypeID = Connector.CreateParameter("@ScheduleType", ScheduleType);
            }
            else
            {
                Parameter_ScheduleTypeID = Connector.CreateNullParameter("@ScheduleType", typeof(byte));
                Parameter_ScheduleTypeID.Direction = ParameterDirection.Output;
            }
            var ScheduleItems = Connector.GetEntities<Models.Device.IrrigationScheduleItem>(this.Connector.CreateProcedureEnumerator("Config.IrrigationSchedule_Get_OverStartTime",
                                                                 new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN),
                                                                       Parameter_ScheduleTypeID
                                                                    })).ToList();
            if ((!ScheduleType.HasValue)
               && Parameter_ScheduleTypeID.Value.GetType() == typeof(byte))
            {
                ScheduleType = (byte)Parameter_ScheduleTypeID.Value;
            }
            else if (!ScheduleType.HasValue)
            {
                ScheduleType = 1;
            }
            return new Models.Device.IrrigationSchedule()
            {
                ScheduleItems = ScheduleItems,
                ScheduleType = (byte)ScheduleType
            };

        }



        public Models.Device.IrrigationSchedule IrrigationSchedule_GetByDay(string SN, int DayNumber, byte ScheduleType)
        {
            var ScheduleItems = Connector.GetEntities<Models.Device.IrrigationScheduleItem>(this.Connector.CreateProcedureEnumerator("Config.IrrigationSchedule_GetByDay",
                                                                 new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN),
                                                                      Connector.CreateParameter("DayNumber",DayNumber),
                                                                      Connector.CreateParameter("ScheduleType",ScheduleType)

                                                                    })).ToList();

            return new Models.Device.IrrigationSchedule()
            {
                ScheduleItems = ScheduleItems,
                ScheduleType = ScheduleType,
            };
        }


        public Models.Device.IrrigationSchedule IrrigationSchedule_Get(string SN, byte? ScheduleType)
        {
            DbParameter Parameter_ScheduleTypeID = null;

            if (ScheduleType.HasValue)
            {
                Parameter_ScheduleTypeID = Connector.CreateParameter("@ScheduleTypeID", ScheduleType);
            }
            else
            {
                Parameter_ScheduleTypeID = Connector.CreateNullParameter("@ScheduleTypeID", typeof(byte));
                Parameter_ScheduleTypeID.Direction = ParameterDirection.Output;
            }

            var ScheduleItems = Connector.GetEntities<Models.Device.IrrigationScheduleItem>(this.Connector.CreateProcedureEnumerator("Config.IrrigationSchedule_Get",
                                                                   new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN),
                                                                      Parameter_ScheduleTypeID
                                                                    })).ToList();
            if ((!ScheduleType.HasValue)
                && Parameter_ScheduleTypeID.Value.GetType() == typeof(byte))
            {
                ScheduleType = (byte)Parameter_ScheduleTypeID.Value;
            }
            else if (!ScheduleType.HasValue)
            {
                ScheduleType = 1;
            }
            return new Models.Device.IrrigationSchedule()
            {
                ScheduleItems = ScheduleItems,
                ScheduleType = (byte)ScheduleType
            };
        }


        public Models.Device.IrrigationSchedule IrrigationSchedule_GetByZone(string SN, int ZoneNum, Byte? ScheduleType)
        {
            DbParameter Parameter_ScheduleTypeID = null;

            if (ScheduleType.HasValue)
            {
                Parameter_ScheduleTypeID = Connector.CreateParameter("@ScheduleTypeID", ScheduleType);
            }
            else
            {
                Parameter_ScheduleTypeID = Connector.CreateNullParameter("@ScheduleTypeID", typeof(byte));
                Parameter_ScheduleTypeID.Direction = ParameterDirection.Output;
            }


            var ScheduleItems = Connector.GetEntities<Models.Device.IrrigationScheduleItem>(this.Connector.CreateProcedureEnumerator("Config.IrrigationSchedule_GetByZone",
                                                                    new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN),
                                                                      Connector.CreateParameter("ZoneNum",ZoneNum),
                                                                      Parameter_ScheduleTypeID
                                                                    })).ToList();
            if ((!ScheduleType.HasValue)
                && Parameter_ScheduleTypeID.Value.GetType() == typeof(byte))
            {
                ScheduleType = (byte)Parameter_ScheduleTypeID.Value;
            }
            else if (!ScheduleType.HasValue)
            {
                ScheduleType = 1;
            }

            return new Models.Device.IrrigationSchedule()
            {
                ScheduleItems = ScheduleItems,
                ScheduleType = (byte)ScheduleType
            };
        }

        public bool IrrigationSchedule_Items_Update(string SN, List<Models.Device.IrrigationScheduleItem> items, byte ScheduleType)
        {
            var Result = false;
            int rowsAffected = 0;
            var Parameter = Connector.CreateParameter("ScheduleItems", CreateSqlMetaDataItem(items)) as SqlParameter;
            Parameter.SqlDbType = SqlDbType.Structured;
            Parameter.TypeName = "Config.ScheduleItem";

            Connector.GetProcedureResultInt32("config.IrrigationSchedule_Update",
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("SN",SN),
                                                                        Parameter,
                                                                        Connector.CreateParameter("ScheduleType",ScheduleType)
                                                                        }
                                                                       ,
                                                                        out rowsAffected,
                                                                        out Result);

            return Result;
        }


        #endregion

        #region Device

        public bool UpdateDeviceLocation(string SN, string lat, string lon)
        {
            bool Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt64("Device.UpdateLocation", new IDataParameter[] {
                                                                        Connector.CreateParameter("SN",SN),
                                                                        Connector.CreateParameter("lat",lat),
                                                                        Connector.CreateParameter("lon",lon)
                                                                    }, out rowsAffected, out Result);
            return Result;
        }

        public Models.Device.DeviceBase GetDevice(string SN)
        {
            return Connector.GetEntity<Models.Device.DeviceBase>(this.Connector.CreateProcedureEnumerator("Device.GetDevice",
                                                                   new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN)
                                                                    }));
        }

        //public bool ConfirmDeviceCode(string SN, string VerificationCode)
        //{
        //    bool Result = false;
        //    int rowsAffected = 0;
        //    var result = Connector.GetProcedureResultInt32("Config.ConfirmDeviceCode",
        //                                                            new IDataParameter[] {
        //                                                              Connector.CreateParameter("SN",SN),
        //                                                                Connector.CreateParameter("VerificationCode",VerificationCode)
        //                                                            }, out rowsAffected, out Result);
        //    return result == 1;

        //}

        public long? AddDevice(string SN, int? ModelID)
        {
            bool Result = false;
            int rowsAffected = 0;
            long DeviceID = Connector.GetProcedureResultInt64("Device.AddDevice", new IDataParameter[] {
                                                                        Connector.CreateParameter("ModelID",ModelID),
                                                                        Connector.CreateParameter("SN",SN)
                                                                    }, out rowsAffected, out Result);
            return DeviceID;
        }

        #endregion

        #region Zone
        public bool Zone_Name_Update(string SN, int zoneNumber, string Name)
        {
            bool Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("Zone.Name_Update", new IDataParameter[] {
                                                                        Connector.CreateParameter("SN",SN),
                                                                        Connector.CreateParameter("Name",Name),
                                                                        Connector.CreateParameter("ZoneNumber",zoneNumber)
                                                                    }, out rowsAffected, out Result);
            return Result;
        }

        public bool Zone_Image_Update(string SN, int ZoneNumber, string url)
        {
            bool Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt64("Zone.Image_Update", new IDataParameter[] {
                                                                        Connector.CreateParameter("URL",url),
                                                                        Connector.CreateParameter("ZoneNumber",ZoneNumber),
                                                                        Connector.CreateParameter("SN",SN)
                                                                    }, out rowsAffected, out Result);
            return Result;
        }

        public Models.Zone.ZoneList[] GetDeviceZones(string SN)
        {
            return Connector.GetEntities<Models.Zone.ZoneList>(this.Connector.CreateProcedureEnumerator("Config.DeviceZones_Get",
                                                                    new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN)
                                                                    })).ToArray();
        }

        public bool ActiveZone_Update(string SN, int ZoneNumber, bool IsEnabled)
        {
            bool Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("Zone.ActiveZone_Update", new IDataParameter[] {
                                                                        Connector.CreateParameter("SN",SN),
                                                                        Connector.CreateParameter("ZoneNumber",ZoneNumber),
                                                                        Connector.CreateParameter("IsEnabled",IsEnabled)
                                                                    }, out rowsAffected, out Result);
            return Result;
        }

        public Models.Zone.ZoneList GetZone(string SN, int ZoneNumber)
        {
            return Connector.GetEntity<Models.Zone.ZoneList>(this.Connector.CreateProcedureEnumerator("Config.DeviceZone_Get",
                                                                   new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN),
                                                                      Connector.CreateParameter("ZoneNumber",ZoneNumber)
                                                                    }));
        }

        #region setting

        public Models.Zone.ZoneIrrigationSettings ZoneSettings_Get(string SN, int ZoneNumber)
        {
            return Connector.GetEntity<Models.Zone.ZoneIrrigationSettings>(this.Connector.CreateProcedureEnumerator("Zone.Settings_Get",
                                                                  new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN),
                                                                      Connector.CreateParameter("ZoneNumber",ZoneNumber)
                                                                    }));
        }

        public bool Zone_UpdateSettings(string SN, int ZoneNumber, Models.Zone.ZoneIrrigationSettings zoneIrrigationSettings)
        {
            bool Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt64("Zone.Settings_Update", new IDataParameter[] {
                                                                        Connector.CreateParameter("Factor",zoneIrrigationSettings.IrrigationFactor),
                                                                        Connector.CreateParameter("IsEnabled",zoneIrrigationSettings.IsEnabled),
                                                                        Connector.CreateParameter("WireColor",zoneIrrigationSettings.WireColor),
                                                                        Connector.CreateParameter("UserAlgorithm",zoneIrrigationSettings.UserWeatherAlgorithm),
                                                                        Connector.CreateParameter("ZoneNumber",ZoneNumber),
                                                                        Connector.CreateParameter("SN",SN)
                                                                    }, out rowsAffected, out Result);
            return Result;
        }

        public Models.Zone.ZoneFlowSensorSettings FlowSensorSettings_Get(string SN, int ZoneNumber)
        {
            return Connector.GetEntity<Models.Zone.ZoneFlowSensorSettings>(this.Connector.CreateProcedureEnumerator("Zone.FlowSensorSettings_Get",
                                                                  new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN),
                                                                      Connector.CreateParameter("ZoneNumber",ZoneNumber)
                                                                    }));
        }

        public bool Zone_FlowSensorSettings_Update(string SN, int ZoneNumber, Models.Zone.ZoneFlowSensorSettings zoneFlowSensorSettings)
        {
            bool Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt64("Zone.FlowSensorSettings_Update", new IDataParameter[] {
                                                                        Connector.CreateParameter("LastObservedFlow",zoneFlowSensorSettings.LastObservedFlow),
                                                                        Connector.CreateParameter("NominalFlow",zoneFlowSensorSettings.NominalFlow),
                                                                        Connector.CreateParameter("ThresholdOverFlow",zoneFlowSensorSettings.ThresholdOverFlow),
                                                                        Connector.CreateParameter("ThresholdUnderFlow",zoneFlowSensorSettings.ThresholdUnderFlow),
                                                                        Connector.CreateParameter("TimeFillDelay",zoneFlowSensorSettings.TimeFillDelay),
                                                                        Connector.CreateParameter("ZoneNumber",ZoneNumber),
                                                                        Connector.CreateParameter("SN",SN)
                                                                    }, out rowsAffected, out Result);
            return Result;
        }

        public bool Zone_SoakSettings_Update(string SN, int ZoneNumber, int? maxCycleTime, int? maxSoakTime)
        {
            bool Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt64("Zone.SoakSettings_Update", new IDataParameter[] {
                                                                        Connector.CreateParameter("MaxSoakTime",maxSoakTime),
                                                                        Connector.CreateParameter("MaxCycleTime",maxCycleTime),
                                                                        Connector.CreateParameter("ZoneNumber",ZoneNumber),
                                                                        Connector.CreateParameter("SN",SN)
                                                                    }, out rowsAffected, out Result);
            return Result;
        }

        #region  Categories
        public Models.Zone.Categories[] Categories_Get(string SN, int ZoneNumber)
        {
            return Connector.GetEntities<Models.Zone.Categories>(this.Connector.CreateProcedureEnumerator("Zone.Categories_Get",
                                                                    new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN),
                                                                      Connector.CreateParameter("ZoneNumber",ZoneNumber)
                                                                    })).ToArray();
        }

        public bool Categories_Update(string SN, int ZoneNumber, Models.Zone.Categories categories)
        {
            bool Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt64("Zone.Categories_Update", new IDataParameter[] {
                                                                        Connector.CreateParameter("SubTypeID",categories.SubTypeID),
                                                                        Connector.CreateParameter("TypeID",categories.TypeID),
                                                                          Connector.CreateParameter("Value",categories.CustomValue),
                                                                        Connector.CreateParameter("ZoneNumber",ZoneNumber),
                                                                        Connector.CreateParameter("SN",SN)
                                                                    }, out rowsAffected, out Result);
            return Result;
        }


        #endregion 

        #endregion

        #region IrrigationSuggestions
        public Models.Zone.ZoneIrrigationSuggestion IrrigationSuggestions_Get(string SN, int ZoneNumber)
        {
            return Connector.GetEntity<Models.Zone.ZoneIrrigationSuggestion>(this.Connector.CreateProcedureEnumerator("Zone.IrrigationSuggestion_Get",
                                                                  new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN),
                                                                      Connector.CreateParameter("ZoneNumber",ZoneNumber)
                                                                    }));
        }

        public bool IrrigationSuggestion_Accept(string SN, int ZoneNumber)
        {
            bool Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("Zone.IrrigationSuggestion_Accept", new IDataParameter[] {
                                                                        Connector.CreateParameter("ZoneNumber",ZoneNumber),
                                                                        Connector.CreateParameter("SN",SN)
                                                                    }, out rowsAffected, out Result);
            return Result;
        }

        public ZoneIrrigationAccumulate ZoneIrrigationAccumulate_Get(string SN, int ZoneNumber)
        {
            return Connector.GetEntity<Models.Zone.ZoneIrrigationAccumulate>(this.Connector.CreateProcedureEnumerator("Zone.Accumulate_Get",
                                                                 new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN),
                                                                      Connector.CreateParameter("ZoneNumber",ZoneNumber)
                                                                   }));
        }

        public bool IrrigationSuggestion_Update(string SN, Models.Zone.ZoneIrrigationSuggestion IrrigationSuggestion)
        {

            bool Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt64("Zone.IrrigationSuggestion_Update", new IDataParameter[] {
                                                                        Connector.CreateParameter("MaximumCycleMinutes",IrrigationSuggestion.Suggestion_MaximumCycleMinutes),
                                                                        Connector.CreateParameter("SoakTimeMinutes",IrrigationSuggestion.Suggestion_SoakTimeMinutes),
                                                                        Connector.CreateParameter("TotalWeeklyDays",IrrigationSuggestion.Suggestion_TotalWeeklyDays),
                                                                        Connector.CreateParameter("TotalWeeklyMinutes",IrrigationSuggestion.Suggestion_TotalWeeklyMinutes),
                                                                        Connector.CreateParameter("RunTimeDaily",IrrigationSuggestion.Suggestion_RunTimeDaily),
                                                                        Connector.CreateParameter("TotalMonthMinutes",IrrigationSuggestion.Suggestion_TotalMonthMinutes),
                                                                        Connector.CreateParameter("ZoneNumber",IrrigationSuggestion.Number),
                                                                        Connector.CreateParameter("SN",SN)
                                                                    }, out rowsAffected, out Result);

            return Result;
        }

        #endregion

        #region Categories Types

        public Models.Zone.AdvisorPlantType[] GetPlantTypes()
        {
            return Connector.GetEntities<Models.Zone.AdvisorPlantType>(this.Connector.CreateProcedureEnumerator("Zone.Category_PlantType_Get",
                                                                 new IDataParameter[] {
                                                                    })).ToArray();
        }

        public Models.Zone.BaseAdvisorOptionalType[] GetSlopeType()
        {
            return Connector.GetEntities<Models.Zone.BaseAdvisorOptionalType>(this.Connector.CreateProcedureEnumerator("Zone.Category_SlopeType_Get",
                                                                 new IDataParameter[] {
                                                                    })).ToArray();
        }

        public Models.Zone.BaseAdvisorOptionalType[] GetSoilTypes()
        {
            return Connector.GetEntities<Models.Zone.BaseAdvisorOptionalType>(this.Connector.CreateProcedureEnumerator("Zone.Category_SoilType_Get",
                                                                 new IDataParameter[] {
                                                                    })).ToArray();
        }

        public Models.Zone.AdvisorSprinklerType[] GetSprinklTypes()
        {
            return Connector.GetEntities<Models.Zone.AdvisorSprinklerType>(this.Connector.CreateProcedureEnumerator("Zone.Category_SprinklType_Get",
                                                                 new IDataParameter[] {
                                                                    })).ToArray();
        }

        public Models.Zone.AdvisorSunExposureType[] GetSunExposureTypes()
        {
            return Connector.GetEntities<Models.Zone.AdvisorSunExposureType>(this.Connector.CreateProcedureEnumerator("Zone.Category_SunExposureType_Get",
                                                                 new IDataParameter[] {
                                                                    })).ToArray();
        }



        #endregion

        #endregion

        #endregion
    }
}
