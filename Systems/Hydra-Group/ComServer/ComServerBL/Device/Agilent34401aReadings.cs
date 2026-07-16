using System;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;

namespace Maba.VCT.CommServer.BL.HydraDevices.Device
{
    /// <summary>
    /// Pure (hardware-independent) interpretation helpers for 34401A READ? values.
    /// Kept separate from <see cref="Agilent34401aBL"/> so the logic is unit-testable.
    /// </summary>
    public static class Agilent34401aReadings
    {
        /// <summary>34401A returns 9.9E37 for an over-range / open reading.</summary>
        public const double OverloadValue = 9.0e37;

        /// <summary>True when the reading is the 34401A over-range / open sentinel (must not be broadcast).</summary>
        public static bool IsOverload(double raw)
        {
            return double.IsNaN(raw) || double.IsInfinity(raw) || Math.Abs(raw) >= OverloadValue;
        }

        /// <summary>
        /// True when the measured quantity is a resistance-based RTD (2- or 4-wire) that must be
        /// converted Ohm→°C. VDC and unset sensors are returned as-is.
        /// </summary>
        public static bool RequiresTemperatureConversion(SensorType sensor)
        {
            return sensor != null &&
                   (sensor.SensType == SensorType.SensorTypes.RTD ||
                    sensor.SensType == SensorType.SensorTypes.FRTD);
        }
    }
}
