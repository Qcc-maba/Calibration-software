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
