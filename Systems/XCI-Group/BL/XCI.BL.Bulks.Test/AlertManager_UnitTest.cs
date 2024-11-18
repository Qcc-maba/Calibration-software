using System;
using System.Collections;
using System.Linq;
using Maba.Hydra2.Systems.XCIGroup.DAL.BulksLayer.Repositories.Common.Models;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Maba.Hydra2.Systems.XCIGroup.BL.Bulks.Test
{
    [TestClass]
    public class AlertManager_UnitTest
    {
        [TestMethod]
        public void XCI_AlertManager_Step1()
        {
            string Device_SN = "TEST000000000001";
            long? DeviceID = null;

            #region preparation

            #region create settings object (for manager)

            var manager_settings = new Bulks.Base.BLSettings();

            #region DAL_BulksLayer

            var alert_esSettings = new DAL.BulksLayer.Repositories.Alerts.ES.AlertsESSettings()
            {               
                Server_URL = @"http://localhost.fiddler:9200"
            };

            manager_settings.DAL_BulksLayer_RepositoriesGenerator = new DAL.BulksLayer.Repositories.RepositoryGenerator()
            {
                Generator_IAlertsRepository = () => new DAL.BulksLayer.Repositories.Alerts.ES.ESAlertsRepository(alert_esSettings)
            };

            #endregion

            #region DAL DataAccessLayer

            manager_settings.DAL_DataAccessLayer_RepositoriesGenerator = new DAL.DataAccessLayer.Repositories.RepositoryGenerator()
            {
                IAdminRepository = () => new DAL.DataAccessLayer.Repositories.Admin.TSQLAdminRepository(),
                IDeviceProcessingRepository = () => new DAL.DataAccessLayer.Repositories.Device.TSQL.TSQLDeviceProcessingRepository()
            };

            #endregion

            #region DAL QueueGenerator

            var aws_sqs_settings = new Connectors.AWS.SQS.SQSSettings()
            {
                //User-name: Queue_Test_User
                AwsAccessKeyId = "AKIAJDEPHWKRRYPG55JA",
                AwsSecretAccessKey = "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",
                QueueName = "HHS_TEST",
                Region = "us-east-1",
                ReceiveMessage = new Connectors.AWS.SQS.ReceiveMessageSettings()
                {
                    MaxNumberOfMessages = 10,
                    VisibilityTimeout = Connectors.AWS.SQS.ReceiveMessageSettings.MAX_VISIBILITY_TIMEOUT,
                    WaitTimeSeconds = 3
                },
                SendMessage = new Connectors.AWS.SQS.SendMessageSettings()
                {
                    DelaySeconds = 0
                }
            };

            manager_settings.DAL_QueueGenerator_Generator = new Connectors.QueueLibrary.QueueGenerator()
            {
                Generate_IQueueConnector = () => new Connectors.QueueLibrary.AWS_SQS.SQSQueueConnector(aws_sqs_settings)
            };

            #endregion

            #endregion

            #region create device

            using (var adminDAL = manager_settings.DAL_DataAccessLayer_RepositoriesGenerator.IAdminRepository())
            {
                var device = adminDAL.GetDevice(Device_SN);
                if (device == null)
                {
                    DeviceID = adminDAL.AddDevice(Device_SN, 1);
                    Assert.IsNotNull(DeviceID);
                    device = adminDAL.GetDevice(Device_SN);
                }

                DeviceID = device.DeviceID;
                Assert.IsNotNull(device);
                Assert.AreEqual(device.SN, Device_SN);
            }

            using (var deviceProccessingConnector = manager_settings.DAL_DataAccessLayer_RepositoriesGenerator.IDeviceProcessingRepository())
            {
                deviceProccessingConnector.DeleteAllAccumulators(DeviceID.Value);
            }

            #endregion

            #region build temp records

            var metadata = new DAL.BulksLayer.Repositories.Common.Models.DeviceRecordMetaData()
            {
                DeviceType = "XCI",
                FirmwareVersion = "1.1.1"
            };

            TempRecord[] Records = new TempRecord[10];

            DateTime d = DateTime.Now;

            var data = new byte[22];

            for (int i = 0; i < Records.Length; i++)
            {
                Records[i] = new TempRecord();

                Records[i].RecordDateT = d.Ticks;
                Records[i].SN = Device_SN;
                Records[i].Metadata = metadata;

                for (int j = 0; j < data.Length; j++)
                {
                    data[j] = (byte)i;
                }
                Records[i].SetData(data);

                d = d.AddSeconds(1);
            }

            #endregion

            #endregion

            var manager = new Bulks.Alerts.AlertsBLManager(manager_settings);

            for (int i = 0; i < 10; i++)
            {
                var stepSize = (1 * TimeSpan.TicksPerSecond);

                foreach (var r in Records)
                {
                    r.RecordDateT += stepSize;
                }

                var results = manager.Step1_Binary(Device_SN, Records.ToArray());

                //validate results
                Assert.AreEqual(results.Length, Records.Length);
               // Assert.AreEqual(i == 0 ? 10 : i, results.Count(r => r));
            }
        }
    }
}
