using System;
using System.Linq;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Collections.Generic;
using System.Data;
using Maba.DAL.BaseDAL.Records;
using System.Security.Cryptography;

namespace Maba.DAL.BaseDAL.UnitTest
{
    public class BaseUnitTest_DbConnector
    {
        #region private members

        private Connectors.DBOperations connector = null;
        private MyRecord[] realRecords = null;

        #endregion

        #region ctor

        public BaseUnitTest_DbConnector(string sectionName)
        {
            connector = new Connectors.DBOperations(sectionName);

            //Assert.IsTrue(connector.ClearRecords());

            realRecords = new MyRecord[10];
            for (int i = 0; i < realRecords.Length; i++)
            {
                realRecords[i] = new MyRecord()
                {
                    RecordID_64 = i,
                    RecordID_32 = i * 10,
                    FirstName = "Monkey" + i.ToString(),
                    LastName = i.ToString() + "Monkey",
                    IsEnabled = i % 2 == 0,
                    CreationDate = new DateTime(2014, 1, 1, i, 0, 0),
                    StationNumber = (byte)i,
                    RecordID_Null = i % 2 != 0 ? (int?)i + 2 : null,
                    Flow = (decimal)i * 0.02m,
                    Data = new byte[i + 2],
                    ProgramNumber = (Int16)i
                };
                realRecords[i].Data[0] = (byte)i;
                realRecords[i].Data[1] = (byte)(i + 1);
            }

            //Assert.IsTrue(connector.AddRecords(realRecords));
        }

        #endregion

        #region private methods




        private IEnumerable<MyRecord> TestTableFunction(int min, int max, string order)
        {
            var records = connector
                .GetRecords_TableFunction(min, max, new string[] { "RecordID_64 " + order })
                .ToArray();

            Assert.IsNotNull(records);
            Assert.AreEqual(records.Length, max - min + 1);


            return records;
        }

        #endregion

        #region Tests
        [TestMethod]
        public virtual void GetValues()
        {
            //connector.ffff();
            Uri();
            while (true)
            {
            }
        }

        //[TestMethod]

        List<CorrectionValues> correctionsValues;
        Tuple<int, int, int, double, double, double> BestTriangle = new Tuple<int, int, int, double, double, double>(0, 0, 0, 0, 0, 0);

        public virtual async void Uri()
        {
            
            
            // from Hydra
            double MeasuredTemperature = 10;
            double MeasuredHumidity = 10;


            // only once
            if (correctionsValues == null)
            {
                correctionsValues = await connector.ffff();
                correctionsValues.AddRange(CalculateCornersValues(correctionsValues));
            }

            var len = correctionsValues.Count;


            double W3min = double.MaxValue;

            for (int i = 0; i < len; i++)
            {
                for (int j = i + 1; j < len; j++)
                {
                    for (int k = j + 1; k < len; k++)
                    {
                        var Item1 = correctionsValues[i];
                        var Item2 = correctionsValues[j];
                        var Item3 = correctionsValues[k];

                        var x1 = (((Item1.TemperatureValue) * (Item3.HumidityValue - Item1.HumidityValue)) + (MeasuredHumidity - Item1.HumidityValue) * (Item3.TemperatureValue - Item1.TemperatureValue)) - (MeasuredTemperature * (Item3.HumidityValue - Item1.HumidityValue));
                        var x2 = ((Item2.HumidityValue - Item1.HumidityValue) * (Item3.TemperatureValue - Item1.TemperatureValue)) - ((Item2.TemperatureValue - Item1.TemperatureValue) * (Item3.HumidityValue - Item1.HumidityValue));
                        
                        if (x2 == 0)
                        {
                            continue;
                        }
                        else
                        {
                            var W1 = x1 / x2;
                            var W2 = (MeasuredHumidity - Item1.HumidityValue - (W1 * (Item2.HumidityValue - Item1.HumidityValue)))
                                / (Item3.HumidityValue - Item1.HumidityValue);

                            if (W1 < 0 || W2 < 0 || W1 + W2 > 1)
                            {
                                continue;
                            }
                            else
                            {
                                var W3 = Math.Sqrt(Math.Pow(Item1.HumidityValue - MeasuredHumidity, 2) + Math.Pow(Item1.TemperatureValue - MeasuredTemperature, 2))
                                       + Math.Sqrt(Math.Pow(Item2.HumidityValue - MeasuredHumidity, 2) + Math.Pow(Item2.TemperatureValue - MeasuredTemperature, 2))
                                       + Math.Sqrt(Math.Pow(Item3.HumidityValue - MeasuredHumidity, 2) + Math.Pow(Item3.TemperatureValue - MeasuredTemperature, 2));
                                if (W3 < W3min)
                                {
                                    W3min = W3;
                                    BestTriangle = new Tuple<int, int, int, double, double, double>(i, j, k, W3min, W1, W2);
                                }
                            }
                        }
                    }
                }
            }

            if (W3min == double.MaxValue)
            {
                /// red flag a HumidityDeviation==0

            }
            var HumidityDeviation = correctionsValues[BestTriangle.Item1].Deviation + (BestTriangle.Item5 *
            (correctionsValues[BestTriangle.Item2].Deviation - correctionsValues[BestTriangle.Item1].Deviation)) + (BestTriangle.Item6 *
            (correctionsValues[BestTriangle.Item3].Deviation - correctionsValues[BestTriangle.Item1].Deviation));

        }

        private List<CorrectionValues> CalculateCornersValues(List<CorrectionValues> c)
        {
            List<CorrectionValues> res = new List<CorrectionValues>();
            // round temp to int rh divide by 5 round to int and multiple by 5;
            //create new 4 lines correction values
            var x1 = new CorrectionValues();
            var x2 = new CorrectionValues();
            var x3 = new CorrectionValues();
            var x4 = new CorrectionValues();

            x1.TemperatureValue = c.Min(x => x.TemperatureValue) - 10;
            x1.HumidityValue = 0;

            x2.TemperatureValue = c.Max(x => x.TemperatureValue) + 10;
            x2.HumidityValue = 0;

            x3.TemperatureValue = c.Min(x => x.TemperatureValue) - 10;
            x3.HumidityValue = 100;

            x4.TemperatureValue = c.Max(x => x.TemperatureValue) + 10;
            x4.HumidityValue = 100;

            var extrimTempMinTemperatureMinHumidity = c.OrderBy(cv => (int)(((int)cv.HumidityValue / 5) * 5)).ThenBy(cv => cv.TemperatureValue).FirstOrDefault();
            var extrimTempMaxTemperatureMinHumidity = c.OrderBy(cv => (int)(((int)cv.HumidityValue / 5) * 5)).ThenByDescending(cv => cv.TemperatureValue).FirstOrDefault();
            var extrimTempMinTemperatureMaxHumidity = c.OrderByDescending(cv => (int)(((int)cv.HumidityValue / 5) * 5)).ThenBy(cv => cv.TemperatureValue).FirstOrDefault();
            var extrimTempMaxTemperatureMaxHumidity = c.OrderByDescending(cv => (int)(((int)cv.HumidityValue / 5) * 5)).ThenByDescending(cv => cv.TemperatureValue).FirstOrDefault();

            double w1eh = ((double)c.Max(cv => cv.TemperatureValue) - (double)extrimTempMinTemperatureMinHumidity.TemperatureValue) / (((double)c.Max(cv => cv.TemperatureValue)) - ((double)c.Min(cv => cv.TemperatureValue)));
            double w2eh = ((double)extrimTempMaxTemperatureMinHumidity.TemperatureValue - ((double)c.Min(cv => cv.TemperatureValue))) / (((double)c.Max(cv => cv.TemperatureValue)) - ((double)c.Min(cv => cv.TemperatureValue)));
            double w3eh = ((double)c.Max(cv => cv.TemperatureValue) - (double)extrimTempMinTemperatureMaxHumidity.TemperatureValue) / (((double)c.Max(cv => cv.TemperatureValue)) - ((double)c.Min(cv => cv.TemperatureValue)));
            double w4eh = ((double)c.Max(cv => cv.TemperatureValue) - (double)extrimTempMaxTemperatureMaxHumidity.TemperatureValue) / (((double)c.Max(cv => cv.TemperatureValue)) - ((double)c.Min(cv => cv.TemperatureValue)));


            var extrimHumMinTemperatureMinHumidity = c.OrderBy(cv => (int)(cv.TemperatureValue)).ThenBy(cv => (int)(((int)cv.HumidityValue / 5) * 5)).FirstOrDefault();
            var extrimHumMaxTemperatureMinHumidity = c.OrderBy(cv => (int)(cv.TemperatureValue)).ThenByDescending(cv => (int)(((int)cv.HumidityValue / 5) * 5)).FirstOrDefault();
            var extrimHumMinTemperatureMaxHumidity = c.OrderByDescending(cv => (int)(cv.TemperatureValue)).ThenBy(cv => (int)(((int)cv.HumidityValue / 5) * 5)).FirstOrDefault();
            var extrimHumMaxTemperatureMaxHumidity = c.OrderByDescending(cv => (int)(cv.TemperatureValue)).ThenByDescending(cv => (int)(((int)cv.HumidityValue / 5) * 5)).FirstOrDefault();


            double w1et = ((double)c.Max(cv => cv.HumidityValue) - (double)extrimHumMinTemperatureMinHumidity.HumidityValue) / (((double)c.Max(cv => cv.HumidityValue)) - ((double)c.Min(cv => cv.HumidityValue)));
            double w2et = ((double)extrimHumMaxTemperatureMinHumidity.HumidityValue - ((double)c.Min(cv => cv.HumidityValue))) / (((double)c.Max(cv => cv.HumidityValue)) - ((double)c.Min(cv => cv.HumidityValue)));
            double w3et = ((double)c.Max(cv => cv.HumidityValue) - (double)extrimHumMinTemperatureMaxHumidity.HumidityValue) / (((double)c.Max(cv => cv.HumidityValue)) - ((double)c.Min(cv => cv.HumidityValue)));
            double w4et = (((double)extrimHumMaxTemperatureMaxHumidity.HumidityValue) - (double)c.Min(cv => cv.HumidityValue)) / (((double)c.Max(cv => cv.HumidityValue)) - ((double)c.Min(cv => cv.HumidityValue)));


            x1.Deviation = ((w1et * extrimHumMinTemperatureMinHumidity.Deviation) + (w1eh * extrimTempMinTemperatureMinHumidity.Deviation)) / (w1et + w1eh);
            x2.Deviation = ((w3et * extrimHumMinTemperatureMaxHumidity.Deviation) + (w2eh * extrimTempMaxTemperatureMinHumidity.Deviation)) / (w3et + w2eh);
            x3.Deviation = ((w2et * extrimHumMaxTemperatureMinHumidity.Deviation) + (w3eh * extrimTempMinTemperatureMaxHumidity.Deviation)) / (w2et + w3eh);
            x4.Deviation = ((w4et * extrimHumMaxTemperatureMaxHumidity.Deviation) + (w4eh * extrimTempMaxTemperatureMaxHumidity.Deviation)) / ((w4et + w4eh));

            res.Add(x1);
            res.Add(x2);
            res.Add(x3);
            res.Add(x4);
            return res;

        }

        [TestMethod]
        public virtual void TableFunction()
        {
            int min = 5;
            int max = 8;
            {
                var records = TestTableFunction(min, max, "ASC").ToArray();

                Assert.IsNotNull(records);
                Assert.AreEqual(records.Length, max - min + 1);

                var filteredRealRecords = realRecords
                    .Where(d => d.RecordID_64 >= min && d.RecordID_64 <= max)
                    .OrderBy(d1 => d1.RecordID_64)
                    .ToArray();

                Assert.AreEqual(records.Length, filteredRealRecords.Length);

                for (int i = 0; i < records.Length; i++)
                {
                    Assert.AreEqual(records[i], filteredRealRecords[i]);
                }
            }

            {
                var records = TestTableFunction(min, max, "DESC").ToArray();

                Assert.IsNotNull(records);
                Assert.AreEqual(records.Length, max - min + 1);

                var filteredRealRecords = realRecords
                    .Where(d => d.RecordID_64 >= min && d.RecordID_64 <= max)
                    .OrderByDescending(d1 => d1.RecordID_64)
                    .ToArray();

                Assert.AreEqual(records.Length, filteredRealRecords.Length);

                for (int i = 0; i < records.Length; i++)
                {
                    Assert.AreEqual(records[i], filteredRealRecords[i]);
                }
            }
        }

        [TestMethod]
        public void ScalarTableFunction()
        {

            int Scalar = connector.GetScalarFunction();
            Assert.AreEqual(realRecords.Length, Scalar);
        }

        [TestMethod]
        public void GetResultInt64_SP()
        {
            bool result = false;
            int rowsAffected = -1;
            long result_int64 = connector.GetResultInt64(out result, out rowsAffected);
            Assert.IsTrue(result);
            Assert.AreEqual(realRecords.Max(u => u.RecordID_64), result_int64);
        }

        [TestMethod]
        public void GetResultInt32_SP()
        {
            bool result = false;
            int rowsAffected = -1;
            int result_int32 = connector.GetResultInt32(out result, out rowsAffected);
            Assert.IsTrue(result);
            Assert.AreEqual(realRecords.Max(u => u.RecordID_32), result_int32);
        }

        [TestMethod]
        public void SelectStatement()
        {
            Assert.IsTrue(connector.SelectStatement());
        }

        [TestMethod]
        public void TableStatement()
        {
            var records = connector.TableStatement();
            Assert.AreEqual(records.Length, realRecords.Length);

            for (int i = 0; i < records.Length; i++)
            {
                Assert.AreEqual(records[i], realRecords[i]);
            }
        }

        [TestMethod]
        public void ProcedureWithOut()
        {
            bool result = false;
            long result_int64 = connector.ProcedureWithOutParameter(out result);
            Assert.IsTrue(result);
            Assert.AreEqual(realRecords.Max(u => u.RecordID_64), result_int64);
        }

        #endregion
    }
}
