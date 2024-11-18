using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Collections.Generic;
using System.Linq;

namespace Maba.VCT.Core.Tests
{
    [TestClass]
    public class ReadWriteLogs : TestInit
    {
        #region Members

        private System.Threading.ManualResetEvent _WriteLogsFlag = new System.Threading.ManualResetEvent(false);
        private System.Threading.ManualResetEvent _ReadLogsFlag = new System.Threading.ManualResetEvent(false);
        private Device.DeviceHost DeviceTested = null;
        Hydra2DeviceResponses device = null;

        private static int port = 50100;
        #endregion
        public ReadWriteLogs() : base(port)
        {

        }

        [TestMethod]
        public void ReadWriteLogsTest()
        {
            System.Threading.Thread.Sleep(1000);
            for (int i = 0; i < MaxRemoteDevices; i++)
            {
                var sn = i.ToString().PadLeft(16, '0');

                device = new Hydra2DeviceResponses()
                {
                    SN = sn,
                    RecordSize = this.RecordSize,
                    Memory = new byte[MemorySize]
                };

                DeviceTested = Server.GetDevice(sn);
                //var request = DeviceTested.ReadLogs(0, 10, 0, Common.API.RemoteProtocolService.DirectionEnum.backward, ReadLogsResponse);
                //request.Wait();
                _ReadLogsFlag.WaitOne();

                //var Hydra2 = _bus.EnumerateClients().FirstOrDefault(a => a.SN == device.SN);

                Assert.IsNotNull(DeviceTested);

                //if (Hydra2 != null)
                //{
                //    Assert.AreEqual(Hydra2.Datalogger_RecordSize, device.RecordSize);
                //    Assert.AreEqual(Hydra2.Datalogger_Memory.Length, device.Memory.Length);

                //    for (int j = 0; j < Hydra2.Datalogger_Memory.Length; j++)
                //    {
                //        Assert.AreEqual(Hydra2.Datalogger_Memory[j], device.Memory[j]);
                //    }
                //}
            }

        }

        private void ReadLogsResponse(Common.API.RemoteProtocolService.NewResponseEventArgs res)
        {
            //var response = res.Response as Common.API.RemoteProtocolService.ReadLogsResponse;

            //res.NextRequest = null;
            //var size = RecordSize * response.ActualCount;
            //var size1 = RecordSize * response.RequestedCount;


            //switch (response.Status)
            //{
            //    case Common.API.RemoteProtocolService.LogStatus.OK:

            //        if (response.HasResponse && response.LogsData != null)
            //        {
            //            Buffer.BlockCopy(response.LogsData, 0, device.Memory, (int)(response.RequestedOffset * device.RecordSize), response.ActualCount * device.RecordSize);
            //        }
            //        if (RecordSize * (response.RequestedOffset + response.ActualCount) < MemorySize)
            //        {
            //            res.NextRequest = new Common.API.RemoteProtocolService.ReadLogsRequest()
            //            {
            //                LogType = response.LogType,
            //                Count = 10,
            //                Offset = response.RequestedOffset + response.ActualCount
            //            };
            //            DeviceTested.ReadLogs(response.LogType, 10, response.RequestedOffset + response.ActualCount, Common.API.RemoteProtocolService.DirectionEnum.backward, ReadLogsResponse);
            //            //DeviceHosts.FirstOrDefault(sn => sn.SN == response.SN).ReadLogs(response.LogType, 10, response.RequestedOffset + response.ActualCount, Common.API.RemoteProtocolService.DirectionEnum.backward, ReadLogsResponse);
            //        }
            //        else
            //        {
            //            _ReadLogsFlag.Set();
            //        }
            //        break;
            //    default:
            //    case Common.API.RemoteProtocolService.LogStatus.InvalidLog:
            //    case Common.API.RemoteProtocolService.LogStatus.Rejected:
            //    case Common.API.RemoteProtocolService.LogStatus.TimedOut:
            //    case Common.API.RemoteProtocolService.LogStatus.NoLogs:
            //        _ReadLogsFlag.Set();
            //        break;
            //    case Common.API.RemoteProtocolService.LogStatus.LoggerEmpty:
            //        break;
            //}

            //if (res.NextRequest == null)
            //{
            //    _ReadLogsFlag.Set();
            //}
        }

    }
    public class Hydra2DeviceResponses
    {
        public string SN { get; set; }
        public byte[] Memory { get; set; }
        public ushort RecordSize { get; set; }

        public Hydra2DeviceResponses()
        {

        }
    }

}
