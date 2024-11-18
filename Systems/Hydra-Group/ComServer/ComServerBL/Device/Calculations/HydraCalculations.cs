using Maba.DAL.BaseDAL;
using Maba.DAL.BaseDAL.Records;
using Maba.VCT.Common.API.RemoteProtocolService;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;

namespace Maba.VCT.CommServer.BL.HydaDevices.Device.Calculations
{
    public class HydraCalculations
    {
        #region Constans

        private const string ID = "@MabaID";
        #endregion

        #region Members

        private MSSqlServer connector;
        private List<double> MeasuredValuesDeviations = new List<double>();
        List<CorrectionValues> correctionValues;
        Tuple<int, int, int, double, double, double> BestTriangle = new Tuple<int, int, int, double, double, double>(0, 0, 0, 0, 0, 0);

        #endregion

        #region Ctor

        public HydraCalculations(MSSqlServer connector)
        {
            this.connector = connector;
        }

        #endregion

        #region Public Methods

        public async void Init(string logerName)
        {
            correctionValues = new List<CorrectionValues>();
            string prucedureName = "GetSensorByName";

            SqlParameter id = new SqlParameter(ID, SqlDbType.NVarChar, 50);
            {
                id.Direction = ParameterDirection.Input;
                id.Value = logerName;
            }

            var DBResults = await connector.RunProcedureAsync(prucedureName, new IDataParameter[] { id });

            while (DBResults.Read())
            {
                var row = new CorrectionValues()
                {
                    TemperatureValue = DBResults.IsDBNull(0) ? double.MinValue : DBResults.GetDouble(0),
                    HumidityValue = DBResults.IsDBNull(1) ? double.MinValue : DBResults.GetDouble(1),
                    Deviation = DBResults.IsDBNull(2) ? double.MinValue : DBResults.GetDouble(2)
                };
                correctionValues.Add(row);
                correctionValues.AddRange(CalculateCornersValues(correctionValues));
            }

        }
        public IEnumerable<double> CalcCalibrationDeviationForTemperature(LogsResponse response)
        {
            double MeasuredValueDeviation = 9999;

            foreach (var MeasuredValue in response.Mesurements)
            {
                for (var c = 0; c < correctionValues.Count - 1; c++)
                {
                    if (MeasuredValue < (double)correctionValues[0].TemperatureValue)
                    {
                        MeasuredValueDeviation = (double)correctionValues[0].Deviation;
                        yield return MeasuredValueDeviation;
                        //TODO Red flag!
                    }
                    else if (MeasuredValue > (double)correctionValues[correctionValues.Count].TemperatureValue)
                    {
                        MeasuredValueDeviation = (double)correctionValues[correctionValues.Count].Deviation;
                        yield return MeasuredValueDeviation;
                        //TODO Red flag!
                    }
                    else if ((double)(correctionValues[c].TemperatureValue) < MeasuredValue && (double)(correctionValues[c + 1].TemperatureValue) > MeasuredValue)
                    {
                        var y31 = (double)(correctionValues[c + 1].Deviation - correctionValues[c].Deviation);
                        var x31 = (double)(correctionValues[c + 1].TemperatureValue - correctionValues[c].TemperatureValue);
                        var x21 = (MeasuredValue - (double)(correctionValues[c].TemperatureValue));
                        MeasuredValueDeviation = (y31 / x31) * (x21);
                    }

                    if (MeasuredValueDeviation != 9999)
                    {
                        MeasuredValuesDeviations.Add(MeasuredValueDeviation);
                    }
                    MeasuredValueDeviation = 9999;
                }
            }
        }
        public IEnumerable<double> CalcCalibrationDeviationForHumidity(LogsResponse response)
        {
            var len = correctionValues.Count;
            List<Tuple<double, double, double>> tripels = new List<Tuple<double, double, double>>();

            for (int i = 0; i < len; i++)
            {
                for (int j = i + 1; j < len; j++)
                {
                    for (int k = j + 1; k < len; k++)
                    {
                        Tuple<double, double, double> tripel = new Tuple<double, double, double>(i, j, k);
                        double w1 = (tripel.Item1) / (1);
                        tripels.Add(tripel);
                    }
                }
            }



            yield return 0;
        }
        public double CalcCalibrationDeviationForTemperatureAndHumidity(LogsResponse response)
        {
            // from Hydra
            double MeasuredTemperature = 10;
            double MeasuredHumidity = 10;

            var len = correctionValues.Count;
            double W3min = double.MaxValue;

            foreach (var item in response.Mesurements)
            {
                for (int i = 0; i < len; i++)
                {
                    for (int j = i + 1; j < len; j++)
                    {
                        for (int k = j + 1; k < len; k++)
                        {
                            var Item1 = correctionValues[i];
                            var Item2 = correctionValues[j];
                            var Item3 = correctionValues[k];

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
            }

            if (W3min == double.MaxValue)
            {
                /// red flag a HumidityDeviation==0

            }
            var HumidityDeviation = correctionValues[BestTriangle.Item1].Deviation + (BestTriangle.Item5 *
            (correctionValues[BestTriangle.Item2].Deviation - correctionValues[BestTriangle.Item1].Deviation)) + (BestTriangle.Item6 *
            (correctionValues[BestTriangle.Item3].Deviation - correctionValues[BestTriangle.Item1].Deviation));

            return HumidityDeviation;
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

        #endregion
    }
}