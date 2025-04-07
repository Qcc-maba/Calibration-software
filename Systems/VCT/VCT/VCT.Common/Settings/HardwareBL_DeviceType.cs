using System.Collections.Generic;

namespace Maba.VCT.CommServer.BL.HydraDevices.Settings
{
    public class HardwareBL_DeviceType
    {
        public enum MeasurementRates : int
        {
            SLOW = 0,
            FAST = 1,
        }
        public MeasurementRates MeasurementRate { get; set; }

        public List<int> Channels { get; set; }
        public int Interval { get; set; }

        public SensorType Sensor { get; set; }
        public int MaxNumOfChannels { get; set; }
        public List<string> Masters { get; set; }

        public HardwareBL_DeviceType()
        {
        }

    }
}