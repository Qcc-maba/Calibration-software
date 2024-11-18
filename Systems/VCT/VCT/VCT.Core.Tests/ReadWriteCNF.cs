using Microsoft.VisualStudio.TestTools.UnitTesting;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.Core.Tests
{
    [TestClass]
    public class ReadWriteCNF : TestInit
    {
        #region Members

        private System.Threading.ManualResetEvent _readCNF_Flag = new System.Threading.ManualResetEvent(false);
        private System.Threading.ManualResetEvent _writeCNF_Flag = new System.Threading.ManualResetEvent(false);
        private byte ElementType = 1;
        private byte ElementOffset = 0;
        private byte[] Data = new byte[] { 0x00, 0x01, 0x02 };
        private static int port = 50050;
        #endregion
        public ReadWriteCNF() : base(port)
        {

        }

        #region Tests

        [TestMethod]
        public void ReadWriteCNFTest()
        {
            System.Threading.Thread.Sleep(1000);

            //for (int i = 0; i < MaxRemoteDevices; i++)
            //{
            //    var sn = i.ToString().PadLeft(16, '0');
            //    var device = Server.GetDevice(sn);
            //    var resWriteCNF = device.WriteCNF(ElementType, ElementOffset, Data, WriteCNFResponse);
            //    resWriteCNF.Wait();
            //    Assert.IsTrue(resWriteCNF.Result.Result);

            //    _writeCNF_Flag.WaitOne();

            //    _readCNFResponse = null;
            //    var resReadCNF = device.ReadCNF(ElementType, ElementOffset, 1, ReadCNFResponse);
            //    resReadCNF.Wait();
            //    _readCNF_Flag.WaitOne();
            //    Assert.IsTrue(resReadCNF.Result.Result);
            //    //Assert.AreEqual(ElementOffset, _readCNFResponse.Items[0].ElementOffset);
            //    //Assert.AreEqual(ElementOffset, _readCNFResponse.Items[0].ElementOffset);
            //    //for (int j = 0; j < Data.Length; j++)
            //    //{
            //    //    Assert.AreEqual(Data[j], _readCNFResponse.Items[0].CNF_Data[j]);
            //    //}
            //}
        }

        //Common.API.RemoteProtocolService.ReadCNFResponse _readCNFResponse;
        //private void ReadCNFResponse(Common.API.RemoteProtocolService.ReadCNFResponse readCNFResponse)
        //{
        //    _readCNFResponse = readCNFResponse;
        //    if (readCNFResponse.Result)
        //    {

        //        _readCNF_Flag.Set();
        //    }
        //}

        //Common.API.RemoteProtocolService.GetFullDateResponse _writeCNFResponse;
        //private void WriteCNFResponse(Common.API.RemoteProtocolService.GetFullDateResponse writeCNFResponse)
        //{
        //    _writeCNFResponse = writeCNFResponse;
        //    if (writeCNFResponse.Result)
        //    {
        //        _writeCNF_Flag.Set();
        //    }
        //}

        #endregion
    }
}
