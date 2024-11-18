using Maba.DAL.BaseDAL;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories.Device.TSQL
{
    public class TSQLDeviceRepository : BaseConnector, IDeviceRepository
    {
        #region CONSTANTS

        public const string DEFAULT_STRING_CONNECTION = "MFSystemAdminDB";

        #endregion

        #region properties

        #endregion

        #region ctor(s)

        private void initCtor()
        {
        }

        public TSQLDeviceRepository()
            : base(DEFAULT_STRING_CONNECTION)
        {
            initCtor();
        }

        public TSQLDeviceRepository(string providerName, string stringConnection)
            : base(providerName, stringConnection)
        {
            initCtor();
        }

        public TSQLDeviceRepository(string stringConnectionSectionName)
            : base(stringConnectionSectionName)
        {
            initCtor();
        }

        #endregion

        #region Implementation of IDeviceRepository

        #region Device CRUD

        public long CreateDevice(string SN, string DeviceName, long? ParentSiteID, int StatusID, string Latitude, string Longitude, int TypeID, int MaxZones = 0)
        {
            var Result = false;
            int rowsAffected = 0;
            long deviceID = Connector.GetProcedureResultInt32("Device.CreateDevice",
                                                          new IDataParameter[]
                                                                        {
                                                                        Connector.CreateParameter("SN",SN),
                                                                        Connector.CreateParameter("TypeID",TypeID),
                                                                        Connector.CreateParameter("DeviceName",DeviceName),
                                                                        Connector.CreateParameter("ParentSiteID",ParentSiteID),
                                                                        Connector.CreateParameter("StatusID",StatusID),
                                                                        Connector.CreateParameter("Lat",Latitude),
                                                                        Connector.CreateParameter("Lon",Longitude),
                                                                        Connector.CreateParameter("MaxZones",MaxZones),
                                                                        },
                                                                        out rowsAffected,
                                                                        out Result);

            return Result ? deviceID : -1;

        }

        public bool DeleteDevice(string SN, long DeviceID)
        {
            var Result = false;
            int rowsAffected = 0;
            long totalAffected = Connector.GetProcedureResultInt32("Device.DeleteDevice",
                                                          new IDataParameter[]
                                                                        {
                                                                        Connector.CreateParameter("SN",SN),
                                                                        Connector.CreateParameter("DeviceID",DeviceID),
                                                                        },
                                                                        out rowsAffected,
                                                                        out Result);

            return Result && totalAffected > 0;

        }

        public DeviceType[] GetDeviceTypes(string FilterName = null)
        {
            return Connector.GetEntities<DeviceType>(this.Connector.CreateProcedureEnumerator("Device.[GetTypes]",
                                                                   new IDataParameter[] {
                                                                      Connector.CreateParameter("FilterName",FilterName)
                                                                    }))
                            .ToArray();
        }

        //public DeviceModel[] GetDeviceModels(long? FilterTypeID = null, string FilterName = null)
        //{
        //    return Connector.GetEntities<DeviceModel>(this.Connector.CreateProcedureEnumerator("Device.[GetModels]",
        //                                                           new IDataParameter[] {
        //                                                              Connector.CreateParameter("FilterTypeID",FilterTypeID),
        //                                                              Connector.CreateParameter("FilterName",FilterName)
        //                                                            }))
        //                    .ToArray();
        //}

        public bool UpdateDeviceName(string SN, string Name)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("Device.UpdateDeviceName",
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("SN",SN),
                                                                        Connector.CreateParameter("Name",Name)},
                                                                        out rowsAffected,
                                                                        out Result);

            return Result;
        }
        public Models.MainDevice GetDevice(long DeviceID)
        {
            return Connector.GetEntity<Models.MainDevice>(this.Connector.CreateProcedureEnumerator("Device.GetDevice_ByID",
                                                                   new IDataParameter[] {
                                                                      Connector.CreateParameter("DeviceID",DeviceID)
                                                                    }));
        }

        public Models.MainDevice GetDevice(string SN)
        {
            return Connector.GetEntity<Models.MainDevice>(this.Connector.CreateProcedureEnumerator("Device.GetDevice",
                                                                   new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN)
                                                                    }));
        }
        /// <summary>
        /// 
        /// </summary>
        /// <param name="UserID"></param>
        /// <param name="SN"></param>
        /// <param name="IsDetachedDevice">True means this device not connected to any site (MainDevice.ParentSiteID=NULL)</param>
        /// <returns></returns>
        public Models.DeviceInfoWithParent GetDeviceInfo(long UserID, string SN, out bool IsDetachedDevice)
        {
            //@DetachedDevice
            var DetachedDevice_Output = Connector.CreateOutParameter("DetachedDevice", false);


            var device = Connector.GetEntity<Models.DeviceInfoWithParent>(this.Connector.CreateProcedureEnumerator("Device.GetDeviceInfo",
                                                                   new IDataParameter[] {
                                                                      Connector.CreateParameter("UserID",UserID),
                                                                      Connector.CreateParameter("SN",SN),
                                                                      DetachedDevice_Output
                                                                    }));

            if (DetachedDevice_Output.Value != DBNull.Value && !(bool)DetachedDevice_Output.Value)
            {
                IsDetachedDevice = false;
                return device;
            }
            else
            {
                IsDetachedDevice = true;
                return null;
            }

        }

        public Models.DeviceType GetDeviceType(string SN)
        {
            return Connector.GetEntity<Models.DeviceType>(this.Connector.CreateProcedureEnumerator("Device.GetDeviceType",
                                                                  new IDataParameter[] {
                                                                      Connector.CreateParameter("SN",SN)
                                                                    }));

        }

        public bool AttachDeviceToSite(long DeviceID, long? SiteID, string lat, string lon)
        {
            int rowsAffected = 0;
            bool result = false;

            Connector.GetProcedureResultInt32("Device.AttachDeviceToSite",
                                                                  new IDataParameter[] {
                                                                      Connector.CreateParameter("DeviceID",DeviceID),
                                                                      Connector.CreateParameter("ParentSiteID",SiteID),
                                                                      Connector.CreateParameter("Lat",lat),
                                                                      Connector.CreateParameter("Lon",lon),
                                                                  }, out rowsAffected,
                                                                    out result);


            return result;
        }

        #endregion

        #region Alert settings

        public bool UpdateAlertsEnabled(string SN, bool AlertsEnabled)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("Device.AlertsSettings_Enable",
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("SN",SN),
                                                                        Connector.CreateParameter("AlertsEnabled",AlertsEnabled)}
                                                                       ,
                                                                        out rowsAffected,
                                                                        out Result);

            return Result;
        }

        public Models.DeviceAlertSettings[] GetDeviceAlertSettings(string SN)
        {
            return Connector.GetEntities<Models.DeviceAlertSettings>(this.Connector.CreateProcedureEnumerator("Device.AlertsSettings_Get",
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("SN",SN)
                                                                        })).ToArray();
        }

        public bool UpdateDeviceAlertSettings(string SN, Models.DeviceAlertSettings item)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("Device.AlertsSettings_Update",
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("SN",SN),
                                                                        Connector.CreateParameter("IsEnable",item.IsEnable),
                                                                        Connector.CreateParameter("IsSMSEnable",item.IsSMSEnable),
                                                                        Connector.CreateParameter("IsEmailEnable",item.IsEmailEnable),
                                                                        Connector.CreateParameter("AlertCode",item.AlertCode)}
                                                                       ,
                                                                        out rowsAffected,
                                                                        out Result);

            return Result;
        }

        #endregion

        #endregion
    }
}
