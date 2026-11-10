using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;

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

        /// <summary>
        /// MBA-1007: the sensor the operator associated with each channel, whose certificate compensates
        /// that channel's readings. Set from the web app's SensorsAssociation and never saved to the file.
        /// <see cref="Masters"/> is the station's own master and also the logger's routing key; compensating
        /// every channel with it is what MBA-1007 found on the bench (sensor 31-98 chosen, 21-449 applied).
        /// Empty until the app associates a sensor, and then the file's master is used, as before.
        /// </summary>
        [JsonIgnore]
        public ChannelMasterMap ChannelMasters
        {
            get { return _channelMasters; }
            set
            {
                _channelMasters = value ?? ChannelMasterMap.Empty;
                ChannelMastersChanged?.Invoke(_channelMasters);
            }
        }
        private ChannelMasterMap _channelMasters = ChannelMasterMap.Empty;

        /// <summary>
        /// MBA-1007 (re-review of #41): raised on every assignment, on the WebSocket thread, even when the
        /// map is unchanged - each association of a Confirm assigns. The BL uses it to load the sensors'
        /// certificates as they are associated, rather than at the next scan, and to ask again about a
        /// sensor that had none: a Confirm with the same setup does not re-init, so nothing else would.
        /// </summary>
        public event Action<ChannelMasterMap> ChannelMastersChanged;

        public HardwareBL_DeviceType()
        {
        }

    }

    /// <summary>
    /// MBA-1007: which sensor compensates each channel. Immutable and swapped whole: it is written on the
    /// WebSocket receive thread and read on the logger's poll thread, so a reader always holds one
    /// consistent map without taking a lock.
    /// </summary>
    public sealed class ChannelMasterMap
    {
        public static readonly ChannelMasterMap Empty = new ChannelMasterMap(new Dictionary<int, string>(), null);

        private ChannelMasterMap(IReadOnlyDictionary<int, string> byChannel, string last)
        {
            ByChannel = byChannel;
            Last = last;
        }

        /// <summary>The sensor each channel was associated with, by channel number.</summary>
        public IReadOnlyDictionary<int, string> ByChannel { get; }

        /// <summary>
        /// The last association's sensor. A channel no association named is labelled with the last
        /// association on its way to the app (ServerCore's fallback label), so it is compensated with the
        /// same sensor - a reading must not be shown as one sensor's and corrected with another's.
        /// </summary>
        public string Last { get; }

        /// <summary>True until the app has associated a sensor.</summary>
        public bool IsEmpty => ByChannel.Count == 0 && Last == null;

        /// <summary>The sensor that compensates <paramref name="channel"/>, or null when none was associated.</summary>
        public string MasterFor(int channel)
        {
            return ByChannel.TryGetValue(channel, out var master) ? master : Last;
        }

        /// <summary>Every sensor named, each once, for loading their certificates.</summary>
        public IEnumerable<string> AllMasters()
        {
            return ByChannel.Values.Concat(Last == null ? Enumerable.Empty<string>() : new[] { Last })
                                   .Distinct(StringComparer.OrdinalIgnoreCase);
        }

        /// <summary>
        /// A copy with <paramref name="channels"/> associated with <paramref name="master"/>.
        /// <paramref name="replace"/> drops every other channel first, for the association that is the
        /// whole channel list (no LoggerConfiguration on that connection), the same as its channels and
        /// labels are replaced.
        /// </summary>
        public ChannelMasterMap With(IEnumerable<int> channels, string master, bool replace)
        {
            var next = replace ? new Dictionary<int, string>() : ByChannel.ToDictionary(kv => kv.Key, kv => kv.Value);
            foreach (var channel in channels ?? Enumerable.Empty<int>()) next[channel] = master;
            return new ChannelMasterMap(next, master);
        }

        /// <summary>
        /// A copy with no channel associated, keeping <see cref="Last"/>. What a LoggerConfiguration leaves:
        /// it clears the logger's channel labels, so until the associations that follow it arrive every
        /// channel is labelled with the last association - and compensated with the same sensor.
        /// </summary>
        public ChannelMasterMap WithoutChannels()
        {
            return ByChannel.Count == 0 ? this : new ChannelMasterMap(new Dictionary<int, string>(), Last);
        }

        /// <summary>For the log: "11,12,13=31-98; 14=21-675".</summary>
        public override string ToString()
        {
            if (ByChannel.Count == 0) return Last == null ? "none" : "all=" + Last;
            return string.Join("; ", ByChannel.GroupBy(kv => kv.Value, StringComparer.OrdinalIgnoreCase)
                                             .Select(g => string.Join(",", g.Select(kv => kv.Key).OrderBy(c => c)) + "=" + g.Key));
        }
    }
}
