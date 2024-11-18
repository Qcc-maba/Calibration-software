using System;
using System.Linq;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Test.Repositories.Device
{
    [TestClass]
    public class DeviceProcessingRepository_Test
    {
        [TestMethod]
        public void Accumulators()
        {
            string Device_SN = "TEST000000000001";
            long DeviceID = 0;
            string AccType = "MyAccType";

            #region create device

            using (var adminConnector = new DataAccessLayer.Repositories.Admin.TSQLAdminRepository())
            {
                var device = adminConnector.GetDevice(Device_SN);

                if (device == null)
                {
                    DeviceID = adminConnector.AddDevice(Device_SN, 1).GetValueOrDefault(-1);
                }
                else
                {
                    DeviceID = device.DeviceID;
                }

                Assert.IsNotNull(DeviceID);
                Assert.IsTrue(DeviceID >= 0);
            }

            #endregion

            using (var connector = new DataAccessLayer.Repositories.Device.TSQL.TSQLDeviceProcessingRepository())
            {
                Assert.IsTrue(connector.DeleteAllAccumulators(DeviceID));
                var accumulators_afterDelete = connector.GetDeviceAccumulators(DeviceID);
                Assert.AreEqual(accumulators_afterDelete.Length, 0);

                var device = connector.GetDeviceWithAccmulators(Device_SN);
                Assert.IsNotNull(device);
                Assert.AreEqual(device.SN, Device_SN);
                var now = DateTime.Now;

                #region insert accumulator

                var accumulators = new DAL.DataAccessLayer.Models.Device.DeviceAccumulator[5];
                //we would like to test accumulators in variety of scenarios such as
                //  *A* START =  NULL, END =  NULL
                //  *B* START != NULL, END =  NULL
                //  *C* START =  NULL, END != NULL      (!!! usually no relevant, not covered in test !!!)
                //  *D* START != NULL, END !=  NULL

                //loop 2 and more -> CASE *D*
                for (int loop1 = 0; loop1 < 6; loop1++)
                {
                    now = now.AddHours(1);
                    int totalAccumulators = 0;

                    for (int accIndex = 0; accIndex < accumulators.Length; accIndex++)
                    {
                        var accType = AccType + $"{loop1}_{accIndex}";

                        //-----Start & test it-----
                        //CASE *A*
                        var originalAcc = accumulators[accIndex] = new DAL.DataAccessLayer.Models.Device.DeviceAccumulator()
                        {
                            AccType = accType,
                            DeviceID = DeviceID,
                            StartTicks = now.Ticks,
                            Start_Value = "1234_begin",
                        };
                        Assert.IsTrue(connector.UpdateTimer_StartPoint(DeviceID, accumulators[accIndex]));
                        CheckAccumulatorsEffect(DeviceID, true, false, connector, accumulators, accIndex, AccType + $"{loop1}_");

                        //-----End & test it-----
                        now = now.AddSeconds(1);

                        //CASE *B*
                        accumulators[accIndex] = new DAL.DataAccessLayer.Models.Device.DeviceAccumulator()
                        {
                            AccType = accType,
                            DeviceID = DeviceID,
                            EndTicks = now.Ticks,
                            End_Value = "1234_end"
                        };
                        Assert.IsTrue(connector.UpdateTimer_EndPoint(DeviceID, accumulators[accIndex]));
                        CheckAccumulatorsEffect(DeviceID, false, true, connector, accumulators, accIndex, AccType + $"{loop1}_");

                        //and set the accumulator to have all properties
                        accumulators[accIndex].StartTicks = originalAcc.StartTicks;
                        accumulators[accIndex].Start_Value = originalAcc.Start_Value;

                        totalAccumulators = CheckAccumulatorsEffect(DeviceID, true, true, connector, accumulators, accIndex, AccType + $"{loop1}_");
                    }

                    var accumulators_copy = connector.GetDeviceAccumulators(DeviceID);
                    Assert.AreEqual(accumulators_copy.Length, (loop1 + 1) * accumulators.Length);
                }

                #endregion
            }
        }

        private int CheckAccumulatorsEffect(long DeviceID,
            bool CompareStart, bool CompareEnd,
            DataAccessLayer.Repositories.Device.TSQL.TSQLDeviceProcessingRepository connector,
            Models.Device.DeviceAccumulator[] accumulators,
            int accIndex, string filterType)
        {
            var accumulators_copy = connector.GetDeviceAccumulators(DeviceID);
            if (!String.IsNullOrEmpty(filterType))
            {
                accumulators_copy = accumulators_copy
                                        .Where(a => a.AccType.StartsWith(filterType))
                                        .ToArray();
            }

            for (int j = 0; j <= accIndex; j++)
            {
                CompareAccumulators(CompareStart, CompareEnd, accumulators_copy[j], accumulators[j]);
            }

            return accumulators_copy.Length;
        }

        private void CompareAccumulators(bool CompareStart, bool CompareEnd,
            DAL.DataAccessLayer.Models.Device.DeviceAccumulator a1,
            DAL.DataAccessLayer.Models.Device.DeviceAccumulator a2)
        {
            Assert.AreEqual(a1.AccType, a2.AccType);
            Assert.AreEqual(a1.DeviceID, a2.DeviceID);

            if (CompareStart)
            {
                Assert.AreEqual(a1.StartTicks, a2.StartTicks);
                Assert.AreEqual(a1.Start_Value, a2.Start_Value);
                Assert.AreEqual(a1.StartDateTimeView, a2.StartDateTimeView);
            }

            if (CompareEnd)
            {
                Assert.AreEqual(a1.EndTicks, a2.EndTicks);
                Assert.AreEqual(a1.End_Value, a2.End_Value);
                Assert.AreEqual(a1.EndDateTimeView, a2.EndDateTimeView);
            }
        }
    }
}
