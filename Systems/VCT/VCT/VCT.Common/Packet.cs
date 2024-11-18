using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Common
{
    public class Packet
    {
        #region Members
        public string Command { get; private set; }
        public string Response { get; private set; }

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

        public Packet(string response)
        {
            Response = response;
        }
        public Packet(string command, bool wait4Respons)
        {
            Command = command;
            Wait4Respons = wait4Respons;
        }
        #endregion

        //#region  public Method
        public string ToString()
        {
            return string.IsNullOrEmpty(Response) ? Command : Response;
        }
        public byte[] ToBytes()
        {
            return ASCIIEncoding.ASCII.GetBytes(Command);
        }

    }
}
