using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Maba.VCT.Clients.Demo.Hydra2
{
    public class Client_Hydra2 : Clients.Demo.Client
    {
        #region Properties

        #endregion

        #region Members
        //public byte EventUpdateIndex = 0;
        //private ushort ConfigID = 0;
        // private DateTime SendUpdate = DateTime.Now;
        #endregion

        #region Ctor

        public Client_Hydra2(string address, int port, string sn)
            : base(address, port, sn)
        {

        }

        #endregion

        #region Private methods

        /*private void GenearteEventUpdate()
        {
            if (ComLayer != null && EventUpdateIndex < 10)
            {

                byte _type = EventUpdateIndex;
                byte _subType = EventUpdateIndex;
                byte[] _data = new byte[12];
                for (int i = 1; i < _data.Length; i++)
                {
                    _data[i] = EventUpdateIndex;
                }
                _data[0] = (byte)_data.Length;
                var p = Core.Device.Hydra2ProtocolHelper.BuildEventUpdate(_type, _subType, _data);
                this.ComLayer.SendBytes(p.ToBytes());
                EventUpdateIndex++;
            }
        }*/

        #endregion

        #region override from Client

        protected override void OnTimer()
        {
        }

        protected virtual void OnConnect()
        {

        }

        protected override void OnPacket(Common.Packet p)
        {

        }
        protected virtual void OnUpdateMetadata()
        {
            this.DeviceMetadata = new Common.IdentificationInfo(this.SN)
            {
                AppVersion = new Version("1.2.3.4"),
                App2Version = new Version("5.6.7.8"),
                DeviceModel = new Version("9.10.11.12"),
                MaxPacketSize = 1024
            };
        }
        #endregion


    }
}
