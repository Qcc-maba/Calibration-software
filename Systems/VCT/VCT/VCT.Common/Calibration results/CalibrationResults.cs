using Maba.VCT.Accessories;
using Maba.VCT.Common.Calibration_results;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common
{
    public class CalibrationResults
    {
        #region Members

        public List<Sample> MasterValues { get; set; }
        public List<Sample> MeasuredValues { get; set; }

        public List<Sample> MasterSecondValues { get; set; }
        public List<Sample> MeasuredSecondValues { get; set; }

        public double UniformityMaxChannel { get; set; }
        public double UniformityMinChannel { get; set; }

        /// <summary>
        /// Key: Channel number, Value: Max or Min value
        /// </summary>
        public MyReaderWriterLockSlim<Dictionary<int, double>> Stability = new MyReaderWriterLockSlim<Dictionary<int, double>>(new Dictionary<int, double>());

        #endregion

        #region Properties
        private readonly ConcurrentDictionary<int, double> min = new ConcurrentDictionary<int, double>();
        private readonly ConcurrentDictionary<int, double> max = new ConcurrentDictionary<int, double>();
        private readonly ConcurrentDictionary<int, double> stability = new ConcurrentDictionary<int, double>();
        #endregion

        #region Ctor

        public CalibrationResults()
        {
            MasterValues = new List<Sample>();
            MeasuredValues = new List<Sample>();
            Stability = new MyReaderWriterLockSlim<Dictionary<int, double>>();
        }

        #endregion

        #region Public methods

        public void CalcUniformity()
        {
            UniformityMaxChannel = MasterValues.Max(x => x.Value);
            UniformityMinChannel = MasterValues.Min(x => x.Value);
        }
        public void CalcStability(DateTime from, DateTime to)
        {
            var min = new Dictionary<int, double>();
            var max = new Dictionary<int, double>();
            var stability = new Dictionary<int, double>();
            foreach (var item in MasterValues.Where(item => item.SampleDate >= from && item.SampleDate <= to))
            {
                if (!max.ContainsKey(item.ChannelNumber) && !min.ContainsKey(item.ChannelNumber))
                {
                    min.Add(item.ChannelNumber, item.Value);
                    max.Add(item.ChannelNumber, item.Value);
                }
                else
                {
                    if (max[item.ChannelNumber] < item.Value)
                    {
                        max[item.ChannelNumber] = item.Value;
                    }
                    if (min[item.ChannelNumber] > item.Value)
                    {
                        min[item.ChannelNumber] = item.Value;
                    }
                }
            }
            foreach (var key in max.Keys)
            {
                stability[key] = max[key] - min[key];
            }
            Stability.MyWriteLock((dic) =>
            {
                dic.Clear();
                foreach (var kvp in stability)
                {
                    dic[kvp.Key] = kvp.Value;
                }
            });
        }

        public void CalcStability()
        {
            foreach (var item in MasterValues)
            {
                // Update min and max values for each channel
                min.AddOrUpdate(item.ChannelNumber, item.Value, (key, oldValue) => Math.Min(oldValue, item.Value));
                max.AddOrUpdate(item.ChannelNumber, item.Value, (key, oldValue) => Math.Max(oldValue, item.Value));
            }

            // Calculate stability for each channel
            foreach (var key in max.Keys)
            {
                stability[key] = max[key] - min[key];
            }

            // Update the global Stability dictionary
            Stability.MyWriteLock((dic) =>
            {
                dic.Clear();
                foreach (var kvp in stability)
                {
                    dic[kvp.Key] = kvp.Value;
                }
            });
        }
    }

    #endregion
}
