using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Maba.VCT.DIGI.APIProtocol
{
    public class APIProtocol
    {
        #region Members

        private int Flag_len = 0;
        private bool Flag_esc = false;
        private bool Flag_First_7E = false;
        private List<byte> _Buffer = new List<byte>();
        private int MaximumAggregate = 2048;
        private List<RemoteEndpoint> LinkedNodes { get; set; }

        public Accessories.MyReaderWriterLockSlim<List<RemoteEndpoint>> LinkedNodes_SLIM { get; private set; }
        private DateTime? APISessionTime = null;

        #endregion

        #region Public properties

        public byte CurrentFrameID { get; private set; }

        public ComLayer.IComLayer InternalComLayer { get; private set; }

        public bool IsClosed { get; private set; }

        public bool IsConnected
        {
            get
            {
                return InternalComLayer != null && InternalComLayer.IsConnected;
            }
        }

        #endregion

        #region Events

        public event PacketDelegate PacketReceived; //PacketEventArgs
        public event PacketDelegate PacketSent;     //PacketEventArgs 
        public event NotificationDelegate NewNodeNotification; //NewNodeNotificationEventArgs

        #endregion

        #region Ctor(s)

        public APIProtocol(ComLayer.IComLayer c)
        {
            LinkedNodes_SLIM = new Accessories.MyReaderWriterLockSlim<List<RemoteEndpoint>>();
            APISessionTime = DateTime.Now;
            LinkedNodes = new List<RemoteEndpoint>();
            InternalComLayer = c;
            InternalComLayer.DataReceived += ComLayer_DataReceived;
            InternalComLayer.LayerClosed += InternalComLayer_Destroy;
        }

        #endregion

        #region Private methods

        void InternalComLayer_Destroy(object sender, ComLayer.DestroyedEventArgs e)
        {
            if (InternalComLayer != null)
            {
                InternalComLayer.DataReceived -= ComLayer_DataReceived;
                InternalComLayer.LayerClosed -= InternalComLayer_Destroy;
                InternalComLayer = null;
            }
        }

        void ComLayer_DataReceived(object sender, ComLayer.DataReceivedEventArgs e)
        {
            for (int i = e.Offset; i < e.Count + e.Offset; i++)
            {
                if (e.Data[i] == 0x7e && !Flag_First_7E)
                {
                    Flag_esc = false;
                    Flag_First_7E = true;

                    _Buffer.Add(e.Data[i]);
                }
                else if (Flag_First_7E)
                {
                    if (e.Data[i] == 0X7D && (Flag_len == _Buffer.Count - 4))
                    {
                        handlePacket(_Buffer.ToArray());
                        Flag_First_7E = false;
                        Flag_esc = false;
                        Flag_len = 0;
                        _Buffer.Clear();
                    }
                    else if (e.Data[i] == 0X7D)
                    {
                        Flag_esc = true;
                    }
                    else
                    {
                        _Buffer.Add(Flag_esc ? (byte)(e.Data[i] ^ 0x20) : e.Data[i]);
                        Flag_esc = false;

                        if (_Buffer.Count == 3)
                        {
                            Flag_len = _Buffer[1] * 0x100 + _Buffer[2];
                        }
                        else if (_Buffer.Count - 4 == Flag_len)
                        {
                            handlePacket(_Buffer.ToArray());
                            Flag_First_7E = false;
                            Flag_esc = false;
                            Flag_len = 0;
                            _Buffer.Clear();
                        }
                    }
                }
                if (_Buffer.Count > MaximumAggregate)
                {
                    Flag_First_7E = false;
                    Flag_esc = false;
                    Flag_len = 0;
                    _Buffer.Clear();
                }
            }
        }

        private void handleNewNode(RemoteEndpoint newNode)
        {
            LinkedNodes_SLIM.MyUpdateLock((list) =>
            {
                if (!list.Contains(newNode))
                {
                    LinkedNodes_SLIM.MyWriteLock((list2) =>
                    {
                        list2.Add(newNode);
                    });
                }
            });

            if (NewNodeNotification != null)
            {
                NewNodeNotification(this, new NewNodeNotificationEventArgs(newNode));
            }
        }

        private RemoteEndpoint Search(Func<RemoteEndpoint, bool> match)
        {
            lock (this.LinkedNodes)
            {
                RemoteEndpoint temp = null;

                LinkedNodes_SLIM.MyReadLock(list =>
                {
                    temp = list.FirstOrDefault(match);
                });
                return temp;
                //return LinkedNodes.FirstOrDefault(match);
            }
        }

        private void handlePacket(byte[] packetData)
        {
            Packets.APIPacket p = null;

            switch (packetData[3])
            {
                case Packets.Node_Identification_Indicator.FRAME_TYPE:
                    var _mac = new byte[8];
                    p = new Packets.Node_Identification_Indicator(packetData);

                    Buffer.BlockCopy(p.API_IdentifierSpecificData, 1, _mac, 0, _mac.Length);

                    StringBuilder sb = new StringBuilder();
                    sb.Clear();
                    byte[] temp = new byte[20];

                    for (int i = 0; i < 20; i++)
                    {
                        if (p.API_IdentifierSpecificData[i + 22] != 0x00)
                        {
                            sb.Append(p.API_IdentifierSpecificData[i + 22].ToString("X2"));
                        }
                        else break;
                    }
                    string NI2 = sb.ToString();
                    var newNode1 = new RemoteEndpoint(_mac, NI2, this, this.InternalComLayer.ParentTunnel);

                    handleNewNode(newNode1); // add to API_List
                    break;

                case Packets.ATCommand.FRAME_TYPE:
                    p = new Packets.ATCommand(packetData);
                    break;
                case Packets.ATCommand_Response.FRAME_TYPE:

                    var atResponse = new Packets.ATCommand_Response(packetData);
                    p = atResponse;

                    if (atResponse.AT_Command == "ND" && packetData.Count() > 9) //  genrated Common.Packet can be 9 bytes (dosn't have NI and address)
                    {

                        sb = new StringBuilder();
                        sb.Clear();
                        for (int i = 0; i < 20; i++)
                        {
                            if (atResponse.API_IdentifierSpecificData[i + 15] != 0x00)
                            {
                                sb.Append(atResponse.API_IdentifierSpecificData[i + 15].ToString("X2"));
                            }
                            else break;
                        }
                        string NI = sb.ToString();

                        _mac = new byte[8];
                        Buffer.BlockCopy(atResponse.API_IdentifierSpecificData, 7, _mac, 0, _mac.Length);

                        var newNode = new RemoteEndpoint(_mac, NI, this, this.InternalComLayer.ParentTunnel);
                        handleNewNode(newNode);
                    }
                    break;
                case Packets.RemoteATCommand.FRAME_TYPE:
                    p = new Packets.RemoteATCommand(packetData);
                    break;
                case Packets.RemoteATCommand_Response.FRAME_TYPE:
                    p = new Packets.RemoteATCommand_Response(packetData);
                    break;
                case Packets.Transmit_Request.FRAME_TYPE:
                    p = new Packets.Transmit_Request(packetData);
                    break;
                case Packets.ZigBeeReceivePacket.FRAME_TYPE:
                    p = new Packets.ZigBeeReceivePacket(packetData);

                    var receivedData = p as Packets.ZigBeeReceivePacket;

                    RemoteEndpoint n = Search(a => a.CompareMAC(receivedData.DestAddress_64_Bit));

                    if (n == null)
                    {
                        n = new RemoteEndpoint(receivedData.DestAddress_64_Bit, null, this, this.InternalComLayer.ParentTunnel);
                        handleNewNode(n);
                    }

                    n.HandlePacket(p);

                    break;
                case Packets.Transmit_Status.FRAME_TYPE:
                    p = new Packets.Transmit_Status(packetData);
                    break;
                case Packets.TxReques64Bit.FRAME_TYPE:
                    p = new Packets.TxReques64Bit(packetData);
                    break;
                case Packets.TxReques16Bit.FRAME_TYPE:
                    p = new Packets.TxReques16Bit(packetData);
                    break;
                case Packets.RxPacket64Bit.FRAME_TYPE:
                    p = new Packets.RxPacket64Bit(packetData);
                    break;
                case Packets.RxPacket16Bit.FRAME_TYPE:
                    p = new Packets.RxPacket16Bit(packetData);
                    break;
                default:
                case Packets.GenericPacket.FRAME_TYPE:
                    p = new Packets.GenericPacket(packetData);
                    break;
            }

            if (PacketReceived != null)
            {
                PacketReceived(this, new PacketEventArgs(p));
            }
        }

        #endregion

        #region Public methods

        protected byte GetNextFrameID()
        {
            byte _c = 0;
            lock (this)
            {
                CurrentFrameID += 1;
                _c = CurrentFrameID;
            }

            return _c;
        }

        public void Close()
        {
            try
            {
                var c = InternalComLayer;

                if (c != null)
                {
                    InternalComLayer_Destroy(this, null);

                    c.Close();
                    InternalComLayer = null;
                }
            }
            catch { }

            RemoteEndpoint[] tempList = null;
            LinkedNodes_SLIM.MyWriteLock((list) =>
            {
                {
                    tempList = list.ToArray();
                    list.Clear();
                }
            });

            foreach (var item in tempList)
            {
                try
                {
                    item.Close();
                }
                catch { }
            }

            IsClosed = true;
        }

        public bool SendPacket(Packets.APIPacket p)
        {
            if (InternalComLayer != null)
            {
                lock (InternalComLayer)
                {
                    if (PacketSent != null)
                    {
                        PacketSent(this, new PacketEventArgs(p));  // update the form
                    }

                    if (p is Packets.APIPacket_FramedID)
                    {
                        ((Packets.APIPacket_FramedID)p).SetFrameID(GetNextFrameID());
                    }

                    this.InternalComLayer.SendBytes(p.ToBytes());

                    return true;
                }
            }
            return false;
        }

        public void Timer()
        {
            // timer api (Node Discovery, RSSI..)
            if (DateTime.Now - APISessionTime > TimeSpan.FromMinutes(10))
            {
                APISessionTime = DateTime.Now;

                List<string> _atCommands = new List<string>() { "ND",/* "DB" */};//  Node Discovery , RSSI
                for (int i = 0; i < _atCommands.Count; i++)
                {
                    this.SendPacket(new Packets.ATCommand(_atCommands[i]));
                }
            }
        }

        #endregion
    }

}