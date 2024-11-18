using System;
using System.Linq;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Collections.Generic;

namespace Maba.VCT.Core.Tests
{
    [TestClass]
    public class ReadWriteMemory : TestInit
    {
        #region Properties
        public int _readTestAddress { get; private set; }
        public byte[] _readTestData { get; private set; }
        public int mem_count = 3;
        ushort[] adresses { get; set; }
        ushort[] values { get; set; }
        //Common.API.RemoteProtocolService.WriteMemoryItem.ElementDataTypes[] dataTypes { get; set; }
        #endregion

        #region Members
        private static int port = 50150;
        private System.Threading.ManualResetEvent _readMemoryFlag = new System.Threading.ManualResetEvent(false);
        private System.Threading.ManualResetEvent _writeMemoryFlag = new System.Threading.ManualResetEvent(false);
        #endregion

        #region ctor

        public ReadWriteMemory() : base(port)
        {

        }

        #endregion

        //[TestMethod]
        //public void ReadWriteMemoryTest()
        //{
        //    adresses = new ushort[mem_count];
        //    values = new ushort[mem_count];
        //    dataTypes = new Common.API.RemoteProtocolService.WriteMemoryItem.ElementDataTypes[mem_count];
        //    System.Threading.Thread.Sleep(1000);
        //    var rand = new Random();

        //    //check one byte for 1 and 2 registers write and double write
        //    //check word for 1 and 2 registers write and double write
        //    //check dbword for 1 and 2 registers write and double write
        //    for (int i = 0; i < MaxRemoteDevices; i++)
        //    {
        //        for (int mem_type = 1; mem_type < 3; mem_type++)
        //        {
        //            for (mem_count = 1; mem_count <= 3; mem_count++)
        //            {
        //                var device = Server.GetDevice(i.ToString().PadLeft(16, '0'));
        //                for (int j = 0; j < mem_count; j++)
        //                {
        //                    adresses[j] = (ushort)rand.Next(0x100, 0xFF99);
        //                    values[j] = (ushort)rand.Next(0x100, 0xFF99);
        //                    dataTypes[j] = mem_type == 1 ? Common.API.RemoteProtocolService.WriteMemoryItem.ElementDataTypes.Byte : Common.API.RemoteProtocolService.WriteMemoryItem.ElementDataTypes.Word;
        //                }


        //                Action<Common.API.RemoteProtocolService.WriteMemoryResponse> write_callback = (res) =>
        //                {
        //                    _writeMemoryFlag.Set();
        //                };

        //                var x = device.WriteMemory(adresses, values, dataTypes, write_callback);
        //                x.Wait();

        //                _writeMemoryFlag.WaitOne();

        //                for (int j = 0; j < mem_count; j++)
        //                {
        //                    ushort DataLength = (ushort)Math.Pow((byte)dataTypes[j], 2);

        //                    Action<Common.API.RemoteProtocolService.PrintTypeResponse> read_callback = (res) =>
        //                    {
        //                        if (res.Items == null || res.Items.Length != mem_count)
        //                        {
        //                            Assert.Fail();
        //                        }
        //                        else
        //                        {
        //                            for (int memIndex = 0; memIndex < res.Items.Length; memIndex++)
        //                            {
        //                                Assert.IsTrue(res.Items[memIndex].DataLen == DataLength);
        //                            }
        //                        }
        //                        Assert.AreEqual(adresses[j], res.Items[j].AddressRequested);
        //                        for (int dev = 0; dev < MaxRemoteDevices; dev++)
        //                        {

        //                            for (int k = 0; k < res.Items[dev].Data.Length; k++)
        //                            {
        //                                if ((byte)dataTypes[0] == 0x01)
        //                                {
        //                                    Assert.AreEqual(res.Items[dev].Data[k], values[k] & 0x00ff);
        //                                }
        //                                else
        //                                {
        //                                    Assert.AreEqual(res.Items[dev].Data[k], values[k]);
        //                                }
        //                            }
        //                        }

        //                        _readMemoryFlag.Set();
        //                    };

        //                    for (j = 0; j < mem_count; j++)
        //                    {
        //                        var x1 = device.ReadMemory(adresses[j], (byte)dataTypes[i], read_callback);
        //                        _readMemoryFlag.WaitOne();
        //                        Assert.IsTrue(x1.Result.Result);
        //                    }
        //                }
        //            }
        //        }
        //    }
        //}

    }
}