using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories.Device
{
    public interface IDeviceProcessingRepository : IDisposable
    {
        Models.DeviceInfo GetDeviceInfo(string SN);
        Models.DeviceAccumulator[] GetDeviceAccumulators(long DeviceID);
        bool AddAccumulator(long DeviceID, Models.DeviceAccumulator Accumulator);
        bool UpdateAccumulator(Models.DeviceAccumulator Accumulator);
        bool UpdateAccumulator(string SN, string AccType, DateTime date);
        bool DeleteAccumulator(long DeviceID);


        IEnumerable<Models.UserInfo> GetUserToSendEmail(long SiteID, long DeviceID, long Code);
        bool UpadteAlertManagement(long SiteID, long DeviceID, long Code, DateTime LastDate, out int interval);
        bool IsAlertActiveItem(long SiteID, long DeviceID, long Code, DateTime utc_now);
    }
}
