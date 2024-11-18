using System;
using System.Linq;
using System.Text;
using System.Collections.Generic;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.BulksLayer.Test.Repositories.Alerts.ES
{
    /// <summary>
    /// Summary description for ES
    /// </summary>
    [TestClass]
    public class XCI_DAL_Alerts_ES
    {
        public XCI_DAL_Alerts_ES()
        {

            //
            // TODO: Add constructor logic here
            //
        }

        private TestContext testContextInstance;

        /// <summary>
        ///Gets or sets the test context which provides
        ///information about and functionality for the current test run.
        ///</summary>
        public TestContext TestContext
        {
            get
            {
                return testContextInstance;
            }
            set
            {
                testContextInstance = value;
            }
        }

        #region Additional test attributes
        //
        // You can use the following additional attributes as you write your tests:
        //
        // Use ClassInitialize to run code before running the first test in the class
        // [ClassInitialize()]
        // public static void MyClassInitialize(TestContext testContext) { }
        //
        // Use ClassCleanup to run code after all tests in a class have run
        // [ClassCleanup()]
        // public static void MyClassCleanup() { }
        //
        // Use TestInitialize to run code before running each test 
        // [TestInitialize()]
        // public void MyTestInitialize() { }
        //
        // Use TestCleanup to run code after each test has run
        // [TestCleanup()]
        // public void MyTestCleanup() { }
        //
        #endregion

        #region private methods

        private BulksLayer.Repositories.Alerts.ES.ESAlertsRepository GetConnector()
        {
            var alert_esSettings = new BulksLayer.Repositories.Alerts.ES.AlertsESSettings()
            {
                Server_URL = @"http://localhost.fiddler:9200"
            };

            var esConnector = new BulksLayer.Repositories.Alerts.ES.ESAlertsRepository(alert_esSettings);

            return esConnector;
        }

        #endregion

        [TestMethod]
        public void Test_TempRecords()
        {
            string Device_SN = "1234567890";

            #region create temp records

            var Records = new BulksLayer.Repositories.Common.Models.TempRecord[10];

            DateTime d = DateTime.Now;
            var metadata = new BulksLayer.Repositories.Common.Models.DeviceRecordMetaData()
            {
                DeviceType = "XCI",
                FirmwareVersion = "1.1.1"
            };

            var data = new byte[22];

            for (int i = 0; i < Records.Length; i++)
            {
                Records[i] = new BulksLayer.Repositories.Common.Models.TempRecord(d);

                Records[i].SN = Device_SN;
                Records[i].Metadata = metadata;

                for (int j = 0; j < data.Length; j++)
                {
                    data[j] = (byte)i;
                }
                Records[i].SetData(data);

                d = d.AddMilliseconds(1);
            }

            #endregion

            #region Insert Records

            using (var connector = GetConnector())
            {
                var insertResults = connector.AddTempRecords(Records);
                Assert.IsNotNull(insertResults);
                Assert.IsTrue(insertResults.All(r => r.Success));
            }

            #endregion

            System.Threading.Thread.Sleep(1000);

            #region get the records back

            using (var connector = GetConnector())
            {
                var returnedRecords = connector.GetTempRecords(Device_SN,
                    Records.Min(r => r.RecordDate),
                    Records.Max(r => r.RecordDate),
                    1, Records.Length);
                Assert.IsNotNull(returnedRecords);
                Assert.IsTrue(returnedRecords.All(r => r != null));
                Assert.AreEqual(Records.Length, returnedRecords.Length);

                returnedRecords = returnedRecords
                                    .OrderBy(r => r.RecordDateT)
                                    .ToArray();
                Records = Records
                                    .OrderBy(r => r.RecordDateT)
                                    .ToArray();

                for (int i = 0; i < returnedRecords.Length; i++)
                {
                    Assert.IsNotNull(returnedRecords[i].Metadata.DeviceType);
                    Assert.AreEqual(Records[i].RecordDateT, returnedRecords[i].RecordDateT);
                    Assert.AreEqual(Records[i].SN, returnedRecords[i].SN);
                    Assert.AreEqual(Records[i].Data, returnedRecords[i].Data);
                    Assert.AreEqual(Records[i].Metadata.DeviceType, returnedRecords[i].Metadata.DeviceType);
                }
            }

            #endregion
        }
    }
}
