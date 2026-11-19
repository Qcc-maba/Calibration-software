using System;

namespace Maba.VCT.CommServer.BL.HydraDevices.Device.Calculations
{
    /// <summary>
    /// MBA-831: follows a precision master's converted readings against its working range and says when an
    /// excursion starts or ends, so the 34401A raises one alert per excursion rather than one per reading.
    /// Thread-safe: the BL's init (Confirm, the power-cycle recovery) resets it while a READ? reply may be
    /// observing (review of #63).
    /// </summary>
    public class MasterWorkRangeMonitor
    {
        /// <summary>Nothing to report.</summary>
        public const int NoChange = 2;

        /// <summary>
        /// An excursion ends only once the reading is back inside by this much (review of #63). A bath settled at
        /// a range end (200 degC on 21-214's -80 to 200) reads 199.998, 200.002, 199.999, ... and would otherwise
        /// start a new excursion every other reading. 0.1 degC is well above a settled bath's scatter and well
        /// below the degrees by which coefficients go wrong outside their range.
        /// </summary>
        public const double ReArmMarginCelsius = 0.1;

        private readonly HydraCalculations _hc;
        private readonly object _lock = new object();
        private int _side;
        private string _master;

        public MasterWorkRangeMonitor(HydraCalculations hc)
        {
            _hc = hc;
        }

        /// <summary>Forgets the current excursion, so a master still outside is reported again.</summary>
        public void Reset()
        {
            lock (_lock)
            {
                _side = 0;
                _master = null;
            }
        }

        /// <summary>
        /// Records a reading. Returns -1 or +1 when an excursion below or above starts, 0 when one ends, and
        /// <see cref="NoChange"/> otherwise. <paramref name="range"/> is the master's range as ASCII text.
        /// </summary>
        public int Observe(string masterId, double celsius, out string range)
        {
            lock (_lock)
            {
                if (!string.Equals(masterId, _master, StringComparison.OrdinalIgnoreCase))
                {
                    _master = masterId;
                    _side = 0;
                }

                var side = _hc.CompareToMasterWorkRange(masterId, celsius, out range);
                if (side == _side)
                    return NoChange;

                // nominally back inside: the excursion is over only once the reading is clearly in
                if (side == 0 && _hc.CompareToMasterWorkRange(masterId, celsius, out _, ReArmMarginCelsius) != 0)
                    return NoChange;

                _side = side;
                return side;
            }
        }
    }
}
