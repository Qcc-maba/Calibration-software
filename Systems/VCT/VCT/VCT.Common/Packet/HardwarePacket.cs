using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common
{
    public class HardwarePacket : IPacket
    {
        #region Members
        public DateTime CreationDate { get; private set; }
        public string Command { get; private set; }
        public string Response { get; private set; }
        public float FloatData { get; private set; }

        /// <summary>
        /// MBA-967: when the instrument took the reading, in the PC's local time, for an instrument
        /// that records it. Null means "now" - the time the packet is sent is the only time known.
        /// A logger is read by polling, so the moment a reading reaches the app lags its scan by a
        /// varying amount; stamping it with the send time made evenly spaced scans look uneven.
        /// </summary>
        public DateTime? MeasuredAt { get; set; }


        public bool Wait4Respons { get; private set; }
        public bool OK
        {
            get
            {
                return (Command != null && Command.Contains("=>")) || (Response != null && Response.Contains(Environment.NewLine));
            }
            private set { }
        }
        #endregion

        #region ctor(s)
        public HardwarePacket(float response)
        {
            CreationDate = DateTime.Now;
            FloatData = response;
        }

        public HardwarePacket(string response)
        {
            CreationDate = DateTime.Now;
            Response = response;
        }
        public HardwarePacket(string command, bool wait4Respons)
        {
            Command = command;
            CreationDate = DateTime.Now;
            Wait4Respons = wait4Respons;
        }
        #endregion

        //#region  public Method
        public override string ToString()
        {
            return string.IsNullOrEmpty(Response) ? Command : Response;
        }
        public byte[] ToBytes()
        {
            return ASCIIEncoding.ASCII.GetBytes(Command);
        }

    }
}
