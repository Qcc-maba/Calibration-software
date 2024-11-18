using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories.Device
{
    public interface IDeviceRepository : IDisposable
    {
        #region Device CRUD

        long CreateDevice(string SN, string DeviceName, long? ParentSiteID, int StatusID, string Latitude, string Longitude, int TypeID, int MaxZones = 0);
        bool DeleteDevice(string SN, long DeviceID);
        Models.DeviceType[] GetDeviceTypes(string FilterName = null);
        bool UpdateDeviceName(string SN, string Name);
        AdminLayer.Models.DeviceInfoWithParent GetDeviceInfo(long UserID, string SN, out bool IsDetachedDevice);
        AdminLayer.Models.MainDevice GetDevice(long DeviceID);
        AdminLayer.Models.MainDevice GetDevice(string SN);
        AdminLayer.Models.DeviceType GetDeviceType(string SN);
        bool AttachDeviceToSite(long DeviceID, long? SiteID, string lat, string lot);

        #endregion

        #region Alert Setting

        AdminLayer.Models.DeviceAlertSettings[] GetDeviceAlertSettings(string SN);

        bool UpdateAlertsEnabled(string SN, bool AlertsEnabled);

        bool UpdateDeviceAlertSettings(string SN, AdminLayer.Models.DeviceAlertSettings item);

        #endregion

    }
}
