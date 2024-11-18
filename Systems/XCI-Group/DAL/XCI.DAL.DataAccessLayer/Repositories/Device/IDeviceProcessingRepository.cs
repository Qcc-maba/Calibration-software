using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Repositories.Device
{
    public interface IDeviceProcessingRepository : IDisposable
    {
        Models.Device.DeviceInfo GetDeviceInfo(string SN);
        Models.Device.DeviceInfo GetDeviceWithAccmulators(string SN);
        Models.Device.DeviceAccumulator[] GetDeviceAccumulators(long DeviceID);
        bool UpdateTimer_StartPoint(long DeviceID, Models.Device.DeviceAccumulator Accumulator);
        bool UpdateTimer_EndPoint(long DeviceID, Models.Device.DeviceAccumulator Accumulator);
        bool DeleteAccumulator(long DeviceID, long TimerID);
        bool DeleteAllAccumulators(long DeviceID);
        bool IsAlertActiveItem(long DeviceID, long Code, DateTime utc_now);
    }
}
