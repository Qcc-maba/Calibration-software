using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Maba.VCT.Clients.Demo
{
    public class Client
    {
        #region properties

        public string SN { get; set; }

        public ushort ConfigID { get; private set; } = 0;
        //public List<Common.API.RemoteProtocolService.CNFItem> _CNFList { get; set; }

        public DateTime? ConnectionTime { get; private set; }
        public DateTime? NextConnectionTime { get; private set; }
        public TimeSpan ClockOffset { get; set; }

        public byte[] Datalogger_Memory { get; set; }
        public ushort Datalogger_RecordSize { get; set; }
        public DateTime? Datalogger_LastFreezeDate { get; set; }

        public bool IsConnected
        {
            get
            {
                return ComLayer != null && this.ComLayer.IsConnected;
            }
        }

        public string Address { get; private set; }
        public int Port { get; private set; }
        public TimeSpan ConnectInterval { get; set; } = TimeSpan.FromMinutes(1);
        public States State { get; set; } = States.KeepConntected;
        public ComLayer.IComLayer ComLayer { get; private set; }
        public Dictionary<long, byte[]> MemoryRequest { get; private set; }
        public ushort OTA_indexOfPacket { get; private set; }
        public List<byte> OTA_FirmwareData { get; private set; }
        public int OTA_LastSesionID { get; private set; } = -1;

        public virtual ushort PacketMaxSize
        {
            get
            {
                return 1024;
            }
        }

        public virtual Common.IdentificationInfo DeviceMetadata { get; protected set; }

        public bool SendIdentificationPacketUponConnection { get; set; } = true;

        #endregion

        #region members

        private Common.Hydra2ProtocolParser ProtocolParser = null;

        #endregion

        #region enums
        [Flags]
        public enum States : byte
        {
            None,
            KeepConntected,
            ConnectAndDisconnect,
            Silent
        }
        #endregion

        #region Ctor

        public Client(string address, int port, string SN)
        {
            Address = address;
            Port = port;
            this.SN = SN;

            //this._CNFList = new List<Common.API.RemoteProtocolService.CNFItem>();
            MemoryRequest = new Dictionary<long, byte[]>();

            ProtocolParser = new Common.Hydra2ProtocolParser()
            {
                OnPacket = OnPacketRecevied
            };
        }

        #endregion

        #region private methods

        private void ComLayer_DataReceived(object sender, ComLayer.DataReceivedEventArgs e)
        {
            //ProtocolParser.OnData(e.Data, e.Offset, e.Count);
        }

        private void OnPacketRecevied(object sender, Common.PacketEventArgs e)
        {
            //var functionID = (Common.Packet.Functions)e.P.Function;

            //if (e.P.MasterType == Common.Packet.MasterTypes.Client)
            //    return;

            //switch (functionID)
            //{
            //    #region GetTime

            //    case Common.Packet.Functions.Get_Time:

            //        var _responsePacket = e.P.BuildReply(Common.Hydra2ProtocolHelper.BuildGetTimeResponse(ClockOffset));

            //        SendPacket(_responsePacket);

            //        break;
            //    #endregion

            //    #region Set Time

            //    case Common.Packet.Functions.Set_Time:
            //        var x = DateTime.UtcNow - Common.Hydra2ProtocolHelper.ParseDateTime(e.P.Data, 0, 4);
            //        ClockOffset = TimeSpan.Parse(x.Value.ToString());
            //        _responsePacket = null;
            //        if (ClockOffset != null)
            //        {
            //            var setTimeResponse = e.P.BuildReply(Common.Hydra2ProtocolHelper.BuildSetTimeResponse(0x01));
            //            SendPacket(setTimeResponse);
            //        }
            //        else
            //        {
            //            var setTimeResponse = e.P.BuildReply(Common.Hydra2ProtocolHelper.BuildSetTimeResponse(0x00));
            //            SendPacket(setTimeResponse);
            //        }
            //        break;

            //    #endregion

            //    #region Identification

            //    case Common.Packet.Functions.Identification:
            //        OnUpdateMetadata();

            //        var connectData = Common.Hydra2ProtocolHelper.IdentificationPacketResponse(this.DeviceMetadata);
            //        this.SendPacket(e.P.BuildReply(connectData));

            //        break;

            //    #endregion

            //    #region CNF Read

            //    case Common.Packet.Functions.ReadCNF:

            //        var _elementType = Common.Hydra2ProtocolHelper.ReadWord(e.P.Data, 0, true);
            //        var _elementOffset = Common.Hydra2ProtocolHelper.ReadWord(e.P.Data, 2, true);
            //        var _elementQuntity = e.P.Data[5];

            //        if (_elementQuntity > _CNFList.Count)
            //        {
            //            this.SendPacket(e.P.BuildReply(Common.Hydra2ProtocolHelper.BuildReadCNFResponse(0x02, null)));
            //        }
            //        else
            //        {
            //            var type = _CNFList.FirstOrDefault(a =>
            //               a.ElementType == _elementType
            //               && a.ElementOffset == _elementOffset);

            //            if (type != null)
            //            {
            //                this.SendPacket(e.P.BuildReply(Common.Hydra2ProtocolHelper.BuildReadCNFResponse(0x06, type)));
            //            }
            //            else
            //            {
            //                this.SendPacket(e.P.BuildReply(Common.Hydra2ProtocolHelper.BuildReadCNFResponse(0x01, null)));
            //            }
            //        }
            //        break;

            //    #endregion

            //    #region Write CNF

            //    case Common.Packet.Functions.WriteCNF:

            //        var _CNF = Common.Hydra2ProtocolHelper.Parse_CNF(e.P.Data, 0);

            //        foreach (var item in _CNF.Items)
            //        {
            //            if (_CNFList.Count == 0)
            //            {
            //                _CNFList.Add(item);
            //            }
            //            var type = _CNFList.FirstOrDefault(a =>
            //                a.ElementType == item.ElementType
            //                && a.ElementOffset == item.ElementOffset);

            //            if (type == null)
            //            {
            //                _CNFList.Add(item);
            //            }
            //            else
            //            {
            //                type.CNF_Data = item.CNF_Data;
            //            }

            //            ConfigID++;
            //        }

            //        this.SendPacket(e.P.BuildReply(Common.Hydra2ProtocolHelper.BuildWriteCNFResponse(0x06, ConfigID)));
            //        break;
            //    #endregion

            //    #region Datalogger (Freeze)
            //    case Common.Packet.Functions.Freeze:

            //        Datalogger_LastFreezeDate = DateTime.UtcNow;
            //        this.SendPacket(e.P.BuildReply(Common.Hydra2ProtocolHelper.BuildFreezeResponse(0x06, Datalogger_RecordSize)));
            //        break;
            //    #endregion

            //    #region Datalogger (read)

            //    case Common.Packet.Functions.ReadLogs:

            //        if (!Datalogger_LastFreezeDate.HasValue || DateTime.UtcNow - Datalogger_LastFreezeDate.Value > TimeSpan.FromMinutes(5))
            //        {
            //            //return - no freeze (2)
            //            var noFreezeResponse = Common.Hydra2ProtocolHelper.Build_LogsResponse(0x02, null, 0, 0, 0);
            //            this.SendPacket(e.P.BuildReply(noFreezeResponse));
            //        }
            //        else
            //        {
            //            var count = e.P.Data[2];
            //            long offset = Common.Hydra2ProtocolHelper.ReadDBWord(e.P.Data, 4);

            //            if (Datalogger_Memory == null)
            //            {
            //                // empty logs (5)
            //                var emptyLogsResponse = Common.Hydra2ProtocolHelper.Build_LogsResponse(0x05, null, 0, 0, 0);
            //                this.SendPacket(e.P.BuildReply(emptyLogsResponse));
            //            }
            //            else
            //            {
            //                uint startIndex = (uint)(offset * Datalogger_RecordSize);  // in memory , not in array
            //                uint endIndex = startIndex + (uint)(count * Datalogger_RecordSize);

            //                if (startIndex + Datalogger_RecordSize > Datalogger_Memory.Length)
            //                {
            //                    //no log (4)
            //                    var noLogsResponse = Common.Hydra2ProtocolHelper.Build_LogsResponse(0x04, null, 0, 0, 0);
            //                    this.SendPacket(e.P.BuildReply(noLogsResponse));
            //                }
            //                else if (endIndex <= Datalogger_Memory.Length)
            //                {
            //                    //6
            //                    var records = new byte[Datalogger_RecordSize * count];
            //                    Buffer.BlockCopy(Datalogger_Memory, (int)startIndex, records, 0, records.Length);
            //                    var recordsResponse = Common.Hydra2ProtocolHelper.Build_LogsResponse(0x06, records, count, startIndex, 0);
            //                    this.SendPacket(e.P.BuildReply(recordsResponse));
            //                }
            //                else
            //                {
            //                    //7
            //                    while (endIndex > Datalogger_Memory.Length)
            //                    {
            //                        endIndex -= Datalogger_RecordSize;
            //                        count--;
            //                    }
            //                    var records = new byte[Datalogger_RecordSize * count];
            //                    Buffer.BlockCopy(Datalogger_Memory, (int)startIndex, records, 0, records.Length);
            //                    var recordsResponse = Common.Hydra2ProtocolHelper.Build_LogsResponse(0x07, records, count, startIndex, 0);
            //                    this.SendPacket(e.P.BuildReply(recordsResponse));
            //                }
            //            }
            //        }
            //        break;
            //    #endregion

            //    #region OTA (start)

            //    case Common.Packet.Functions.StartDownLoadFirmware:

            //        var SesionID = Common.Hydra2ProtocolHelper.ReadWord(e.P.Data, 0, true);
            //        var FileSize = Common.Hydra2ProtocolHelper.ReadDBWord(e.P.Data, 2);

            //        if (SesionID != OTA_LastSesionID)
            //        {
            //            OTA_LastSesionID = SesionID;
            //            this.SendPacket(Common.Hydra2ProtocolHelper.Build_StartDownLoadFirmwareResponse(0x06, 0, PacketMaxSize));// Ready to start
            //        }
            //        else
            //        {
            //            this.SendPacket(Common.Hydra2ProtocolHelper.Build_StartDownLoadFirmwareResponse(0x07, OTA_indexOfPacket, PacketMaxSize));  // Ready to continue
            //        }
            //        break;
            //    #endregion

            //    #region OTA (get Common.Packet)
            //    case Common.Packet.Functions.GetFirmwarePacket:

            //        var PacketLen = e.P.Data.Length == 6 ? 0 : Common.Hydra2ProtocolHelper.ReadWord(e.P.Data, 2, true);
            //        var ActualLen = e.P.Data.Length - 6;

            //        if (PacketLen == ActualLen)
            //        {
            //            byte[] PacketData = new byte[ActualLen];
            //            Buffer.BlockCopy(e.P.Data, 4, PacketData, 0, PacketLen);
            //            OTA_FirmwareData.AddRange(PacketData);
            //            this.SendPacket(Common.Hydra2ProtocolHelper.Build_CountinuedPacketResponse(0x06));
            //        }
            //        else
            //        {
            //            this.SendPacket(Common.Hydra2ProtocolHelper.Build_CountinuedPacketResponse(0x04));
            //        }
            //        break;
            //    #endregion

            //    #region OTA (finish)
            //    case Common.Packet.Functions.FinishDownLoadFirmware:

            //        var FinishDownLoadFirmwarePacket = Common.Hydra2ProtocolHelper.Build_FinishDownloadFirmwareResponse(0x06);
            //        this.SendPacket(FinishDownLoadFirmwarePacket);
            //        break;
            //    #endregion

            //    #region Write Memory
            //    case Common.Packet.Functions.WriteRT_Data:
            //        //MemoryRequest.AddRange(p.Data);
            //        var write_address = Common.Hydra2ProtocolHelper.ReadWord(e.P.Data, 1, true);

            //        var data_type = e.P.Data[5];

            //        if (data_type == 1)
            //        {
            //            MemoryRequest.Add(write_address, new byte[] { e.P.Data[4] });
            //        }
            //        else
            //        {
            //            MemoryRequest.Add(write_address, new byte[] { e.P.Data[3], e.P.Data[4] });
            //        }

            //        var WriteMemoryPacket = Common.Hydra2ProtocolHelper.Build_WriteMemoryPacketResponse(0x06);
            //        this.SendPacket(e.P.BuildReply(WriteMemoryPacket));
            //        break;
            //    #endregion

            //    #region Read Memory
            //    case Common.Packet.Functions.Read_RT_Value:
            //        var read_address = Common.Hydra2ProtocolHelper.ReadWord(e.P.Data, 0, true);
            //        var read_len = Common.Hydra2ProtocolHelper.ReadWord(e.P.Data, 2, true);

            //        byte[] read_data = null;
            //        if (MemoryRequest.TryGetValue(read_address, out read_data))
            //        {
            //            this.SendPacket(e.P.BuildReply(Common.Hydra2ProtocolHelper.Build_ReadMemoryPacketResponse(e.P.Data, read_data)));
            //        }
            //        else
            //        {
            //            var b = new byte[read_len];
            //            for (int i = 0; i < b.Length; i++)
            //            {
            //                b[i] = (byte)('A' + i);
            //            }
            //            this.SendPacket(e.P.BuildReply(Common.Hydra2ProtocolHelper.Build_ReadMemoryPacketResponse(e.P.Data, b)));
            //        }

            //        break;
            //        #endregion
            //}

            //OnPacket(e.P);
        }

        #endregion

        #region public methods

        public virtual void Timer()
        {
            switch (this.State)
            {
                case States.Silent:
                case States.None:
                    break;
                case States.KeepConntected:
                    if (this.ComLayer == null || !this.ComLayer.IsConnected)
                    {
                        if (!NextConnectionTime.HasValue || DateTime.UtcNow >= NextConnectionTime.Value)
                        {
                            NextConnectionTime = DateTime.UtcNow.Add(ConnectInterval);
                            Connect();
                        }
                    }
                    break;
                case States.ConnectAndDisconnect:
                    if (!NextConnectionTime.HasValue || DateTime.UtcNow >= NextConnectionTime.Value)
                    {
                        NextConnectionTime = DateTime.UtcNow.Add(ConnectInterval);

                        if (this.State.HasFlag(Client.States.ConnectAndDisconnect))
                        {
                            if (ComLayer != null && this.ComLayer.IsConnected)
                            {
                                Disconnect();
                            }
                            else
                            {
                                Connect();
                            }
                        }
                    }
                    break;
            }

            OnTimer();
        }

        public virtual bool Connect()
        {
            if (ComLayer == null || !ComLayer.IsConnected)
            {
                bool result = false;

                if (ComLayer != null)
                {
                    try
                    {
                        ComLayer.Close();
                    }
                    catch
                    {

                    }
                }

                try
                {
                    ComLayer = new ComLayer.SocketCom(Address, Port);
                    ComLayer.DataReceived += ComLayer_DataReceived;
                    ComLayer.Open();

                    ConnectionTime = DateTime.UtcNow;

                    result = true;

                    if (SendIdentificationPacketUponConnection)
                    {
                        OnUpdateMetadata();
                        //var data = Common.Hydra2ProtocolHelper.IdentificationPacketResponse(this.DeviceMetadata);
                        //var p = new Common.Packet(0, 0x11, Common.Packet.MasterTypes.Client, 0x00, 0x00, 0x10, data);
                        //this.SendPacket(p);
                    }

                    OnConnect();
                }
                catch
                {
                    Disconnect();
                }

                return result;
            }
            else
            {
                return true;
            }
        }

        public virtual void Disconnect()
        {
            if (ComLayer != null && this.ComLayer.IsConnected)
            {
                this.ComLayer.Close();
                this.ComLayer = null;
            }
        }

        #endregion

        #region protected methods

        protected void SendPacket(Common.Packet p)
        {
            this.ComLayer.SendBytes(p.ToBytes());
        }

        #endregion

        #region protected virtual methods

        protected virtual void OnPacket(Common.Packet p)
        {

        }

        protected virtual void OnConnect()
        {

        }
        protected virtual void OnTimer()
        {

        }

        protected virtual void OnUpdateMetadata()
        {
            this.DeviceMetadata = new Common.IdentificationInfo(this.SN)
            {
                AppVersion = new Version("1.0.3.160"),
                App2Version = new Version("2.1.2.11"),
                DeviceModel = new Version("2.0.12.12"),
                MaxPacketSize = 1024
            };
        }

        #endregion

        #region Overriden from Object

        public override string ToString()
        {
            return String.Format("{0}", SN);
        }

        #endregion
    }
}
