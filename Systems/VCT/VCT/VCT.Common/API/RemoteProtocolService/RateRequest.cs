using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common.API.RemoteProtocolService
{
    public class RateRequest : BaseRequest
    {

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
        public RateRequest(int intervalSeconds) : this(intervalSeconds, 0, 0)
        {
            IntervalSeconds = intervalSeconds;
        }

        public RateRequest(int intervalSeconds, int intervalMinutes, int intervalHours)
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
