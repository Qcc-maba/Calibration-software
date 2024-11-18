using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common.API.RemoteProtocolService
{
    public class RateRequest : DeviceBaseRequest
    {

        #region Enum
        public enum MeasurementRates : int
        {
            Fast = 0,
            Slow = 1
        }
        #endregion

        #region Members
        public bool IsSetRate { get; private set; }
        public int MeasurementRate { get; private set; }
        public int IntervalHours { get; private set; }
        public int IntervalMinutes { get; private set; }
        public int IntervalSeconds { get; private set; }

        #endregion

        #region Ctor(s)
        public RateRequest()
            : base()
        {
            IsSetRate = true;
        }
        public RateRequest(int intervalHours, int intervalMinutes, int intervalSeconds)
            : base()
        {
            IntervalHours = intervalHours;
            IntervalMinutes = intervalMinutes;
            IntervalSeconds = intervalSeconds;
            IsSetRate = false;
        }
        #endregion
    }
}
