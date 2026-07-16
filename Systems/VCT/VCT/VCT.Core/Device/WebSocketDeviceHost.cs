using Maba.VCT.ComLayer;
using Maba.VCT.ComLayer.Com_Layer;
using Maba.VCT.Common;
using Maba.VCT.Common.Protocol_Parser;
using Maba.VCT.Common.Protocol_Parser.WebSocketMessage;
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
                AssociatedUnits = !string.IsNullOrEmpty(association.Units) ? association.Units : "Celsius";
                AssociatedResolution = !string.IsNullOrEmpty(association.Resolution) ? association.Resolution : "2";
                Libs.Trace.Tracer.Info("[WS] SensorsAssociation: DeviceID={0}, LoggerID={1}, BatchID={2}, Units={3}, Resolution={4}",
                    AssociatedDeviceId, AssociatedLoggerId, AssociatedBatchId, AssociatedUnits, AssociatedResolution);
            }

            var p = new Events.DeviceEventArgs(this, e.P);
            MainEventsBus.Fire_OnIncomingEvent(this, p);
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
}
