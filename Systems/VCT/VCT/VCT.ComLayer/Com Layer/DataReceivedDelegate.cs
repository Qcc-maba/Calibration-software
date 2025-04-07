using System;
using System.Linq;
using System.Text;

namespace Maba.VCT.ComLayer
{
    #region Delegate

    public delegate void DataReceivedDelegate(object sender, DataReceivedEventArgs e);

    #endregion

    public class DataReceivedEventArgs : EventArgs
    {
        #region proeprties
        public string DataString { get;private set; }
        public byte[] Data { get; private set; }
        public float FloatData { get; private set; }
        public int Offset { get; private set; }
        public int Count { get; private set; }

        #endregion

        #region ctor

        public DataReceivedEventArgs(byte[] data, int offset, int count)
            : base()
        {
            Data = data;
            Offset = offset;
            Count = count;
        }
        public DataReceivedEventArgs(string data) : this(ASCIIEncoding.ASCII.GetBytes(data),0,data.Length)
        {
            DataString = data;
        }

        public DataReceivedEventArgs(float response, int offset, int count)
        {
            this.FloatData = response;
            Offset = offset;
            Count = count;
        }
        public DataReceivedEventArgs(ushort[] response, int offset, int count)
        {
            this.Data = response.SelectMany(x => BitConverter.GetBytes(x)).ToArray();
            Offset = offset;
            Count = count;
        }
        #endregion
    }
}