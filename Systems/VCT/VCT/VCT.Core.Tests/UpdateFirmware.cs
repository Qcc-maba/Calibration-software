using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.IO;
using System.Linq;

namespace Maba.VCT.Core.Tests
{
    [TestClass]
    public class UpdateFirmware : TestInit
    {
        //#region Members
        //private System.Threading.ManualResetEvent _UpdateFlag = new System.Threading.ManualResetEvent(false);
        //#endregion

        private static int port = 50200;

        public UpdateFirmware() : base(port)
        {
        }

        [TestMethod]
        public void UpdateFirmwareTest()
        {
            Assert.Fail();

            // create directory 
            string path = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location);
            path = Path.Combine(path, "FirmwareFiles");
            Directory.CreateDirectory(path);

            // create a Code folder
            var code = Path.Combine(path, "eliran");
            Directory.CreateDirectory(code);


            // create file and copy temp arry
            var filePath = Path.Combine(code, "DataFile.DAT");
            var tempArry = new byte[] { 0x01, 0x02, 0x03, 0x04, 0x05 };
            File.WriteAllBytes(filePath, tempArry);

            #region Upload files

            //var x = Server.RemoteUploadFileRequestAsync(null, null, false);
            //x.Wait();
            //Assert.IsFalse(x.Result.Result);

            //x = Server.RemoteUploadFileRequestAsync("eliran", tempArry, false);
            //x.Wait();
            //Assert.IsFalse(x.Result.Result);

            //x = Server.RemoteUploadFileRequestAsync("eliran", null, false);
            //x.Wait();
            //Assert.IsFalse(x.Result.Result);

            //var x = Server.RemoteUploadFileRequestAsync("eliran", null, false);
            //x.Wait();
            //Assert.IsFalse(x.Result.Result);

            //x = Server.RemoteUploadFileRequestAsync("eliran", tempArry, false);
            //x.Wait();
            //Assert.IsFalse(x.Result.Result);


            var firmwareFiles = Directory.GetFiles(code).Where(a => a.Contains("Firmware.DAT")).ToList();

            for (int j = 0; j < MaxRemoteDevices; j++)
            {
                for (int i = 0; i < firmwareFiles.Count; i++)
                {
                    var sn = i.ToString().PadLeft(16, '0');
                    //var device = Server.GetDevice(sn);
                    //var res = device.UpdateFirmware(code);
                    //res.Wait();
                    //_UpdateFlag.WaitOne();
                }
            }
            #endregion
        }

        //private void updateFirwareResponse(Maba.VCT.Common.Device.API.RemoteProtocolService.UpdateFirmwareResponse response)
        //{
        //    Assert.AreEqual(response.PercentageOfPerformance, 200);
        //    _UpdateFlag.Set();

        //}
    }
}
