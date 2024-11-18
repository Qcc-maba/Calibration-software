using System;

namespace Maba.VCT.ComLayer
{
    #region Delegate

    public delegate void DataReceivedDelegate(object sender, DataReceivedEventArgs e);

    #endregion

    public class DataReceivedEventArgs : EventArgs
    {
        #region proeprties

        public byte[] Data { get; private set; }
        public int Offset { get; private set; }
        public int Count { get; private set; }

        public string StringData { get; private set; }
        #endregion

        #region ctor

        public DataReceivedEventArgs(byte[] data, int offset, int count)
            : base()
        {
            Data = data;
            Offset = offset;
            Count = count;
        }
        public DataReceivedEventArgs(string data) : base()
        {
            StringData = data;
            this.Data = System.Text.ASCIIEncoding.ASCII.GetBytes(data);
            this.Offset = 0;
            this.Count = data.Length;
        }
        #endregion
    }
}