using Maba.VCT.ComLayer;
using Maba.VCT.ComLayer.Com_Layer;
using Maba.VCT.Common;
using Maba.VCT.Common.Protocol_Parser;
using Maba.VCT.Common.Protocol_Parser.WebSocketMessage;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using Maba.VCT.Core.Events;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Core.Device
{
    public class WebSocketDeviceHost : IDeviceHost
    {

        #region Events

        private Events.EventsBus MainEventsBus = null;
        private WebSocketProtocolParaser ProtocolParser = null;

        public event Common.PacketDelegate PacketSent;     //PacketEventArgs

        #endregion

        #region ICom Layer Members
        public IDeviceBL BL { get; set; }

        public DateTime IdentificationDate { get; set; }

        public string SN { get; private set; }

        public bool IsConnected
        {
            get
            {
                var com = InternalComLayer;
                return com != null && com.IsConnected;
            }
            private set { }
        }

        public IComLayer InternalComLayer { get; private set; }

        // Sensors association data received from the WebSocket client
        public string AssociatedDeviceId { get; set; }
        public string AssociatedLoggerId { get; set; }
        public string AssociatedBatchId { get; set; }
        public string AssociatedUnits { get; set; }
        public string AssociatedResolution { get; set; }

        /*  MBA-967: several sensors on one logger. One Confirm sends a SensorsAssociation per sensor,
            each naming only that sensor's channels. The Associated* fields above hold ONE association
            and every LoggerData line was stamped with it, so with sensor A on 1-3 and B on 4-6 every
            reading - A's included - was labelled as B's. Each channel now keeps the association that
            named it; Associated* stays as the last association, for channels no association named.

            Written on the WebSocket receive thread, read on the broadcast path: the map is never
            mutated once published. A writer copies it under _channelLabelsLock and swaps the
            reference, so a reader holds a consistent snapshot without taking any lock.  */
        private readonly object _channelLabelsLock = new object();
        private volatile IReadOnlyDictionary<int, ChannelLabel> _channelLabels = new Dictionary<int, ChannelLabel>();

        /*  MBA-967 (review of #21): the loggers this connection has sent a LoggerConfiguration for.
            "A SensorsAssociation adds its channels" is only right when a full channel list came first -
            the logger dialog's Confirm and the calibration graph's saved-setup re-send both do that. A
            client that sends a SensorsAssociation alone (the graph's fallback when the dialog was never
            confirmed, the /websocket-test page) relied on it REPLACING the list: with only adding, the
            default 1-20 could never be narrowed to 1,3,5, and moving from a device on 1-3 to one on 4-6
            left 1-3 scanned and still labelled with the old device. Per connection, like the labels. */
        private readonly object _configuredLoggersLock = new object();
        private readonly HashSet<string> _configuredLoggers = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        /// <summary>
        /// MBA-967: whether this connection has sent a LoggerConfiguration for <paramref name="loggerId"/>,
        /// which decides whether its SensorsAssociations add channels or replace the list.
        /// </summary>
        public bool HasConfiguredLogger(string loggerId)
        {
            var id = (loggerId ?? "").Trim();
            if (id.Length == 0) return false;
            lock (_configuredLoggersLock) { return _configuredLoggers.Contains(id); }
        }

        private void MarkLoggerConfigured(string loggerId)
        {
            var id = (loggerId ?? "").Trim();
            if (id.Length == 0) return;
            lock (_configuredLoggersLock) { _configuredLoggers.Add(id); }
        }

        /// <summary>
        /// MBA-967: the association each channel was named in, by channel number. A snapshot - never
        /// modified after it is returned. Channels absent from it use the Associated* fields.
        /// </summary>
        public IReadOnlyDictionary<int, ChannelLabel> ChannelLabels => _channelLabels;

        #endregion

        #region Ctor

        public WebSocketDeviceHost(EventsBus mainEventsBus, IComLayer layer, string sn)
        {
            this.MainEventsBus = mainEventsBus;
            this.SN = sn;
            ReplaceComLayer(layer);
            ProtocolParser = new WebSocketProtocolParaser()
            {
                OnPacket = handlePacket
            };
        }

        #endregion

        private void handlePacket(object o, Common.PacketEventArgs e)
        {
            if (e.P is SensorsAssociationMessage association)
            {
                AssociatedDeviceId = association.DeviceId;
                AssociatedLoggerId = association.LoggerId;
                AssociatedBatchId = association.BatchId;
                // Left empty when the app sends no Units: this host serves one WebSocket client and
                // has no hardware device in scope, so it cannot know whether the default should be
                // Celsius or Volt. ServerCore resolves it per broadcasting device instead.
                AssociatedUnits = association.Units;
                AssociatedResolution = !string.IsNullOrEmpty(association.Resolution) ? association.Resolution : "2";
                Libs.Trace.Tracer.Info("[WS] SensorsAssociation: DeviceID={0}, LoggerID={1}, BatchID={2}, Units={3}, Resolution={4}",
                    AssociatedDeviceId, AssociatedLoggerId, AssociatedBatchId, AssociatedUnits, AssociatedResolution);

                // MBA-485: the sensor association also carries the channel list — apply it live.
                if (!string.IsNullOrEmpty(association.BatchChannels))
                {
                    var settings = HardwareBL_Settings.Read();
                    string summary;
                    if (HasConfiguredLogger(association.LoggerId))
                    {
                        // MBA-967: a full channel list came first, so this sensor's channels are added to
                        // it, not replacing it - with one SensorsAssociation per sensor, replacing left
                        // only the last sensor's channels scanned.
                        summary = settings.AddWebSocketSensorChannels(association.LoggerId, association.BatchChannels);
                    }
                    else
                    {
                        // No full list on this connection: the association IS the channel list, as before
                        // #21. It replaces the list and the logger's labels, so the scan narrows and a
                        // device no longer calibrated stops being recorded (see _configuredLoggers).
                        ClearChannelLabels(association.LoggerId, association.BatchChannels);
                        summary = settings.ApplyWebSocketConfig(association.LoggerId, null, null, association.BatchChannels);
                    }

                    // MBA-967: these channels are this sensor's - label their readings with it.
                    LabelChannels(association.BatchChannels, new ChannelLabel(
                        AssociatedDeviceId, AssociatedLoggerId, AssociatedBatchId, AssociatedUnits, AssociatedResolution));

                    if (summary != null)
                    {
                        Libs.Trace.Tracer.Info("[WS->HW] Applied channels from SensorsAssociation: {0}", summary);
                        // MBA-974: the line above only updated in-memory settings - push it to the
                        // live instrument too, or it keeps scanning whatever it was told at connect.
                        MainEventsBus.Fire_LiveHardwareReconfigured(this,
                            new Events.LiveHardwareReconfiguredEventArgs(
                                settings.ResolveLiveFamilyKey(association.LoggerId),
                                "SensorsAssociation channel change from web app"));
                    }
                }
            }

            // MBA-485: the web app pushes the operator's logger configuration (rate / interval / channels)
            // over WebSocket. Apply it to the in-memory BL settings so the device is driven by what the
            // logged-in user configured — no DB and no restart. Takes effect on the next scan setup.
            if (e.P is LoggerConfigurationMessage loggerConfig && loggerConfig.Loggers != null)
            {
                var settings = HardwareBL_Settings.Read();
                foreach (var cfg in loggerConfig.Loggers)
                {
                    // MBA-967: a Confirm starts fresh. Its LoggerConfiguration arrives before its
                    // SensorsAssociations, so a sensor removed in the dialog must not keep labelling
                    // its old channels.
                    ClearChannelLabels(cfg.LoggerId, cfg.BatchChannels);
                    MarkLoggerConfigured(cfg.LoggerId);

                    var summary = settings.ApplyWebSocketConfig(cfg.LoggerId, cfg.Rate, cfg.Interval, cfg.BatchChannels);
                    if (summary != null)
                    {
                        Libs.Trace.Tracer.Info("[WS->HW] Applied logger configuration from web app: {0}", summary);
                        // MBA-974: same as SensorsAssociation above - push the change to the live instrument.
                        MainEventsBus.Fire_LiveHardwareReconfigured(this,
                            new Events.LiveHardwareReconfiguredEventArgs(
                                settings.ResolveLiveFamilyKey(cfg.LoggerId),
                                "LoggerConfiguration change from web app"));
                    }
                    else if (HardwareBL_Settings.IsWebSocketConfigHeld(cfg.LoggerId))
                        Libs.Trace.Tracer.Info("[WS->HW] LoggerConfiguration for '{0}': no logger identified yet; held, and applied when it is (MBA-967).", cfg.LoggerId);
                    else
                        Libs.Trace.Tracer.Info("[WS->HW] LoggerConfiguration for '{0}': nothing to apply; kept current settings.", cfg.LoggerId);
                }
            }

            var p = new Events.DeviceEventArgs(this, e.P);
            MainEventsBus.Fire_OnIncomingEvent(this, p);
        }

        /// <summary>MBA-967: labels every channel in <paramref name="batchChannels"/> with <paramref name="label"/>.</summary>
        private void LabelChannels(string batchChannels, ChannelLabel label)
        {
            var channels = HardwareBL_Settings.ParseChannels(batchChannels);
            if (channels.Count == 0) return;

            lock (_channelLabelsLock)
            {
                var next = new Dictionary<int, ChannelLabel>(_channelLabels.Count + channels.Count);
                foreach (var kv in _channelLabels) next[kv.Key] = kv.Value;
                foreach (var ch in channels) next[ch] = label;
                _channelLabels = next;
            }
        }

        /// <summary>
        /// MBA-967: drops the labels of logger <paramref name="loggerId"/> - every channel an
        /// association for that logger named, and every channel the configuration lists.
        /// </summary>
        private void ClearChannelLabels(string loggerId, string batchChannels)
        {
            var id = (loggerId ?? "").Trim();
            var channels = new HashSet<int>(HardwareBL_Settings.ParseChannels(batchChannels));

            lock (_channelLabelsLock)
            {
                var next = new Dictionary<int, ChannelLabel>();
                foreach (var kv in _channelLabels)
                {
                    var sameLogger = id.Length > 0 &&
                        string.Equals((kv.Value.LoggerId ?? "").Trim(), id, StringComparison.OrdinalIgnoreCase);
                    if (!sameLogger && !channels.Contains(kv.Key)) next[kv.Key] = kv.Value;
                }
                if (next.Count != _channelLabels.Count) _channelLabels = next;
            }
        }


        private void OnDisconnection()
        {
            Libs.Trace.Tracer.Info(true, $"#{SN} Disconnected");

            var bl = this.BL;
            if (bl != null)
            {
                bl.OnConnection(false);
            }
        }

        private void OnConnection()
        {
            Libs.Trace.Tracer.Info(true, $"#{SN} Connected");

            var bl = this.BL;
            if (bl != null)
            {
                bl.OnConnection(true);
            }
        }

        public void Disconnect()
        {
            if (!IsConnected)
                return;

            Libs.Trace.Tracer.Info(true, $"#{SN} Self Disconnection");

            var com = this.InternalComLayer;
            com.Close();
            _executer_Destroy();
            MainEventsBus.Fire_DeviceConnection(this, new Events.DeviceConnectionEventArgs(this));

            if (BL != null)
            {
                BL.OnConnection(false);
            }
        }

        public void Dispose()
        {
            Disconnect();
        }

        public void ReplaceComLayer(IComLayer comLayer)
        {
            _executer_Destroy(InternalComLayer);

            //get new (if any. for Pending DeviceHost we kill them by ReplaceComLayer(null))
            if (comLayer != null)
            {
                InternalComLayer = comLayer;
                InternalComLayer.DataReceived += _executer_DataReceived;
                InternalComLayer.LayerClosed += _executer_Destroy;
            }
        }

        private void _executer_Destroy(ComLayer.IComLayer comLayer = null)
        {
            if (comLayer != null)
            {
                comLayer.LayerClosed -= _executer_Destroy;
                comLayer.DataReceived -= _executer_DataReceived;
            }

            if (InternalComLayer != null)
            {
                InternalComLayer.LayerClosed -= _executer_Destroy;
                InternalComLayer.DataReceived -= _executer_DataReceived;
                InternalComLayer = null;
            }
        }

        private void _executer_Destroy(object sender, ComLayer.DestroyedEventArgs e)
        {
            var _com = (ComLayer.IComLayer)sender;
            if (_com != null)
            {
                OnDisconnection();
                _executer_Destroy(_com);
            }
        }

        private void _executer_DataReceived(object sender, ComLayer.DataReceivedEventArgs e)
        {
            if (!string.IsNullOrEmpty(e.DataString))
            {
                ProtocolParser.OnData(e.DataString);
            }
        }


        public void SendPacket(Common.IPacket p)
        {
            var _com = InternalComLayer;

            if (IsConnected && _com != null)
            {
                //change TransactionId when it's out original Common.Packet

                Libs.Trace.Tracer.Info("PACKET <TX> " + p.ToString());

                //_com.SendBytes(p.ToBytes());
                _com.SendString(p.ToString());
                if (PacketSent != null)
                {
                    PacketSent(this, new Common.PacketEventArgs(p));
                }

            }
        }

        public void Timer()
        {
            if (BL != null)
            {
                BL.OnTimer();
            }
            // WebSocket RX is driven by WebSocketCom.RunReceiveLoopAsync (ServerCore); do not poll Receive here.
        }
    }

    /// <summary>
    /// MBA-967: what one SensorsAssociation said about its channels - the fields a LoggerData line
    /// carries for them. Immutable, and equal by value, so readings whose labels are equal travel
    /// in one line (<see cref="ServerCore.BuildLoggerDataLines"/>).
    /// </summary>
    public sealed class ChannelLabel : IEquatable<ChannelLabel>
    {
        public ChannelLabel(string deviceId, string loggerId, string batchId, string units, string resolution)
        {
            DeviceId = deviceId;
            LoggerId = loggerId;
            BatchId = batchId;
            Units = units;
            Resolution = resolution;
        }

        public string DeviceId { get; }
        public string LoggerId { get; }
        public string BatchId { get; }
        public string Units { get; }
        public string Resolution { get; }

        public bool Equals(ChannelLabel other)
        {
            return other != null
                && string.Equals(DeviceId, other.DeviceId, StringComparison.Ordinal)
                && string.Equals(LoggerId, other.LoggerId, StringComparison.Ordinal)
                && string.Equals(BatchId, other.BatchId, StringComparison.Ordinal)
                && string.Equals(Units, other.Units, StringComparison.Ordinal)
                && string.Equals(Resolution, other.Resolution, StringComparison.Ordinal);
        }

        public override bool Equals(object obj) => Equals(obj as ChannelLabel);

        public override int GetHashCode()
        {
            unchecked
            {
                var h = 17;
                h = h * 31 + (DeviceId?.GetHashCode() ?? 0);
                h = h * 31 + (LoggerId?.GetHashCode() ?? 0);
                h = h * 31 + (BatchId?.GetHashCode() ?? 0);
                h = h * 31 + (Units?.GetHashCode() ?? 0);
                h = h * 31 + (Resolution?.GetHashCode() ?? 0);
                return h;
            }
        }
    }
}
