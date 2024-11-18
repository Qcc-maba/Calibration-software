using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.Remoting.Messaging;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common.API.RemoteProtocolService
{
    public class InitChannelsRequest : DeviceBaseRequest
    {
        #region Enum
        public enum ThermocoupleTypes
        {
            J = 0,
            K = 1,
            E = 2,
            T = 3,
            N = 4,
            R = 5,
            S = 6,
            B = 7,
            C = 8,
            DC = 9
        }


        public enum MeasureTypes
        {
            VAC = 0,
            VDC = 1,
            OHMS = 2,
            FREQ = 3,
            TEMP = 4,
            OFF = 5
        }

        #endregion

        #region Members
        public static MeasureTypes MeasureType { get; private set; }
        public ThermocoupleTypes ThermocoupleType { get; private set; }
        public int MaxChannels
        {
            get
            {
                return 20;
            }
            private set { }
        }
        public int ChannleNumber { get; private set; }
        #endregion

        #region Ctor(s)
        public InitChannelsRequest()
            : base()
        {

        }

        public InitChannelsRequest(int channleNumber, MeasureTypes measureType, ThermocoupleTypes thermocoupleType)
           : base()
        {
            ChannleNumber = channleNumber;
            MeasureType = measureType;
            ThermocoupleType = thermocoupleType;
        }
        #endregion
    }
}
