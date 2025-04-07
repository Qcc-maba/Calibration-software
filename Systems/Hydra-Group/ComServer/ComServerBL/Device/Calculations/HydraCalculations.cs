using Maba.DAL.BaseDAL;
using Maba.DAL.BaseDAL.Records;
using Maba.VCT.Common;
using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.Common.Calibration_results;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.Common;
using System.Data.SqlClient;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;

namespace Maba.VCT.CommServer.BL.HydraDevices.Device.Calculations
{
    public class HydraCalculations
    {
        #region Enum
        public enum ConversionUnits
        {
            Kelvin,
            Celsius,
            Fahrenheit,
            Rankine,
            Millivolt,
            Ohm,
        }
        public enum ResultStatus : int
        {
            OK = 0,
            LowValue = 1,
            HighValue = 2,
            WrongValue = 3,
        }
        #endregion

        #region Constans

        //private const string ID = "@MabaID";
        #endregion

        #region Members

        private MSSqlServer connector;
        Dictionary<string, List<CorrectionValues>> correctionValuesDic;
        public CalibrationResults CalibrationResult { get; set; }

        #endregion

        #region Ctor

        public HydraCalculations(MSSqlServer connector)
        {
            this.connector = connector;
            this.correctionValuesDic = new Dictionary<string, List<CorrectionValues>>();
            CalibrationResult = new CalibrationResults();
        }

        #endregion

        #region Public Methods
        public async void Init(List<string> masters)
        {
            if (masters == null || masters.Count == 0)
            {
                Trace.WriteLine("Error in init HC");
                return;
            }
            foreach (string master in masters)
            {
                //await RunProcedure("GetSensorByName", "@MabaID", master);
            }


        }
        public async Task<bool> RunProcedure(string procedureName, string ID, string loggerName)
        {
            Console.WriteLine($"Starting RunProcedure for {procedureName}");
            bool TemperatureFlag = false;
            try
            {
                var corVal = new List<CorrectionValues>();
                SqlParameter id = new SqlParameter(ID, SqlDbType.NVarChar, 50)
                {
                    Direction = ParameterDirection.Input,
                    Value = loggerName
                };

                Console.WriteLine("Calling RunProcedureAsync...");
                DbDataReader dbResults = null;

                try
                {
                    dbResults = await connector.RunProcedureAsync(procedureName, new IDataParameter[] { id });

                    if (dbResults == null)
                    {
                        Console.WriteLine("No results returned from database");
                        return false;
                    }

                    Console.WriteLine("Processing results...");
                    while (dbResults.Read())
                    {
                        List<double> temp = new List<double>();
                        for (int i = 0; i < dbResults.FieldCount; i++)
                        {
                            if (!dbResults.IsDBNull(i))
                            {
                                temp.Add(dbResults.GetDouble(i));
                            }
                        }
                        TemperatureFlag = temp.Count == 2;
                        if (TemperatureFlag)
                        {
                            corVal.Add(new CorrectionValues(temp[0], temp[1]));
                        }
                        else
                        {
                            corVal.Add(new CorrectionValues(temp));
                        }
                    }
                    if (!TemperatureFlag)
                    {
                        corVal.AddRange(CalculateCornersValues(corVal));
                    }
                    correctionValuesDic.Add(loggerName, corVal);
                    return corVal.Count > 0;
                }
                finally
                {
                    //if (dbResults != null && !dbResults.IsClosed)
                    //{
                    //    dbResults.Close();
                    //}
                }
            }
            catch (Exception e)
            {
                Console.WriteLine($"Error in RunProcedure: {e.Message}");
                Console.WriteLine($"Stack trace: {e.StackTrace}");
                return false;
            }
        }
        public void ProcessResults(LogsResponse response, HardwareBL_DeviceType DeviceType)
        {
            Sample s = null;
            Tuple<double, ResultStatus> results = null;
            if (response == null || DeviceType == null || DeviceType.Sensor == null)
            {
                Console.WriteLine("Process results error");
                return;
            }


            switch (DeviceType.Sensor.MeasureType)
            {
                case SensorType.MeasureTypes.None:
                    break;
                case SensorType.MeasureTypes.TEMP:
                    for (int i = 0; i < response.Measurements.Count; i++)
                    {
                        results = CalcCalibrationDeviationForTemperature(response.Measurements[i], DeviceType.Masters.FirstOrDefault());
                        s = new Sample(results.Item1, response.Measurements[i], (int)results.Item2, DeviceType.Channels[i], Sample.Units.Celsius);
                        CalibrationResult.MasterValues.Add(s);
                    }
                    break;
                case SensorType.MeasureTypes.VDC:
                    for (int i = 0; i < response.Measurements.Count; i++)
                    {
                        for (int j = 0; j < response.Measurements.Count; j++)
                        {
                            results = CalcResistentce2TemperatureConvertionITS90(DeviceType.Masters.FirstOrDefault(), response.Measurements[i]);
                            s = new Sample(results.Item1, response.Measurements[i], (int)results.Item2, DeviceType.Channels[i], Sample.Units.Celsius);
                            CalibrationResult.MasterValues.Add(s);
                        }
                    }
                    break;
                case SensorType.MeasureTypes.Resistance:
                    break;
                case SensorType.MeasureTypes.Dew:
                    if (response.Measurements.Count % 1 == 0)
                    {
                        results = CalcCalibrationDeviationForTemperature(response.Measurements[response.Measurements.Count - 1], DeviceType.Masters.FirstOrDefault());
                        s = new Sample(results.Item1, response.Measurements[0], (int)results.Item2, DeviceType.Channels[0], Sample.Units.Celsius);
                        CalibrationResult.MasterValues.Add(s);
                    }
                    else if (response.Measurements.Count % 2 == 0)
                    {
                        var Pdry = CalcCalibrationWithDewPointDeviation(results.Item1);
                        var PDew = CalcCalibrationWithDewPointDeviation(response.Measurements[1]);
                        var HumidityPersent = (PDew.Item1 / Pdry.Item1) * 100;
                        s = new Sample(results.Item1, response.Measurements[0], (int)results.Item2, DeviceType.Channels[0], Sample.Units.Celsius, response.Measurements[1], Sample.Units.Humidity, HumidityPersent);
                        CalibrationResult.MasterValues.Add(s);
                    }
                    break;
                case SensorType.MeasureTypes.Humidity:
                    var Temp = CalcCalibrationDeviationForTemperature(response.Measurements[0], DeviceType.Masters.FirstOrDefault());
                    var Hum = CalcCalibrationDeviationForTemperatureAndHumidity(Temp.Item1, response.Measurements[1], DeviceType.Masters.FirstOrDefault());
                    s = new Sample(Temp.Item1, response.Measurements[0], (int)Temp.Item2, DeviceType.Channels[0], Sample.Units.Celsius, Hum.Item1, Sample.Units.Humidity, double.NaN);
                    CalibrationResult.MasterValues.Add(s);
                    break;
                default:
                    break;
            }

            if (s != null && s.Alert != 3)
            {
                CalibrationResult.CalcStability();
                CalibrationResult.CalcUniformity();
            }


            Console.WriteLine("Number of sampels received: {0}", CalibrationResult.MasterValues.Count);

        }
        #endregion

        #region Temperature Calculations
        public Tuple<double, ResultStatus> CalcCalibrationDeviationForTemperature(double value, string ID)
        {
            if (correctionValuesDic == null || correctionValuesDic.Count == 0)
            {
                return new Tuple<double, ResultStatus>(9999, ResultStatus.WrongValue);
            }
            var CorrctionList = correctionValuesDic[ID];
            if (CorrctionList == null || CorrctionList.Count == 0)
            {
                return new Tuple<double, ResultStatus>(9999, ResultStatus.WrongValue);
            }

            double MesuredValueDeviation = 9999;
            double MesuredTemperature = value;
            Tuple<double, ResultStatus> returnValue;

            CorrctionList.OrderBy(o => o.TemperatureValue);

            for (var c = 0; c < CorrctionList.Count - 1; c++)
            {

                // find the minimal maximal Temperature and deviation 
                var minTemp = CorrctionList.Min(x => x.TemperatureValue);
                var maxTemp = CorrctionList.Max(x => x.TemperatureValue);
                var maxDev = CorrctionList.Where(x => x.TemperatureValue == maxTemp).Select(y => y.Deviation).FirstOrDefault();
                var minDev = CorrctionList.Where(x => x.TemperatureValue == minTemp).Select(y => y.Deviation).FirstOrDefault();


                // Check if the measeured value is low than minimal value 
                if (MesuredTemperature < minTemp)
                {
                    MesuredValueDeviation = minDev;
                    returnValue = new Tuple<double, ResultStatus>(MesuredValueDeviation, ResultStatus.LowValue);
                    return returnValue;

                }
                // Check if the measeured value is high than maximal value 
                else if (MesuredTemperature > maxTemp)
                {
                    MesuredValueDeviation = maxDev;
                    returnValue = new Tuple<double, ResultStatus>(MesuredValueDeviation, ResultStatus.HighValue);
                    return returnValue;
                }
                // find 2 temperature values between the measeured value and calc the deviation 
                else if ((double)(CorrctionList[c].TemperatureValue) < MesuredTemperature && (double)(CorrctionList[c + 1].TemperatureValue) > MesuredTemperature)
                {
                    var y31 = (double)(CorrctionList[c + 1].Deviation - CorrctionList[c].Deviation);
                    var x31 = (double)(CorrctionList[c + 1].TemperatureValue - CorrctionList[c].TemperatureValue);
                    var x21 = (MesuredTemperature - (double)(CorrctionList[c].TemperatureValue));
                    var res = ((y31 / x31) * (x21)) + CorrctionList[c].Deviation;
                    var res2 = ((x21 / x31) * y31) + CorrctionList[c].Deviation;
                    returnValue = new Tuple<double, ResultStatus>(res, ResultStatus.OK);
                    return returnValue;
                }
                // case the measured values equal to the correction value record.  
                else if (MesuredTemperature == CorrctionList[c].TemperatureValue)
                {
                    return new Tuple<double, ResultStatus>(MesuredTemperature - CorrctionList[c].Deviation, ResultStatus.OK);
                }

            }
            return new Tuple<double, ResultStatus>(9999, ResultStatus.WrongValue);

        }
        public Tuple<double, ResultStatus> CalcCalibrationDeviationForTemperatureAndHumidity(double Temperature, double Humidity, string ID)
        {
            var corrctionList = correctionValuesDic[ID];

            if (corrctionList == null || corrctionList.Count == 0)
            {
                return new Tuple<double, ResultStatus>(0, ResultStatus.WrongValue);
            }
            // from Hydra
            double MeasuredTemperature = Temperature;
            double MeasuredHumidity = Humidity;

            Tuple<int, int, int, double, double, double> BestTriangle = new Tuple<int, int, int, double, double, double>(0, 0, 0, 0, 0, 0);


            double W3min = double.MaxValue;

            for (int i = 0; i < corrctionList.Count; i++)
            {
                for (int j = i + 1; j < corrctionList.Count; j++)
                {
                    for (int k = j + 1; k < corrctionList.Count; k++)
                    {
                        var Item1 = corrctionList[i];
                        var Item2 = corrctionList[j];
                        var Item3 = corrctionList[k];

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
                return new Tuple<double, ResultStatus>(0, ResultStatus.WrongValue);
                /// red flag a HumidityDeviation==0
            }
            try
            {
                var HumidityDeviation = corrctionList[BestTriangle.Item1].Deviation + (BestTriangle.Item5 *
                (corrctionList[BestTriangle.Item2].Deviation - corrctionList[BestTriangle.Item1].Deviation)) + (BestTriangle.Item6 *
                (corrctionList[BestTriangle.Item3].Deviation - corrctionList[BestTriangle.Item1].Deviation));
                return new Tuple<double, ResultStatus>(Math.Round(MeasuredHumidity - HumidityDeviation, 2), ResultStatus.OK);
            }
            catch (Exception e)
            {
                Console.WriteLine(e.Message.ToString());
                return new Tuple<double, ResultStatus>(0, ResultStatus.WrongValue);
            }
        }
        public double ClacCalibrationLogarithmicalForVacum(string ID, double value)
        {
            // The deviations are in % of reading.

            //TODO from DB
            double[] MasterUUT = new double[] { 2.01E-07, 2.18E-07, 2.30E-07, 3.16E-07, 4.93E-07, 8.56E-07, 1.34E-06, 1.74E-06, 3.44E-06, 6.68E-06, 8.48E-06 };
            double[] Deviation = new double[] { 234.44, 166.50, 76.92, 0.00, 0.00, 0.00, 0.00, -13.00, -14.43, -15.87, -16.86 };
            value = 2.00E-6;

            double[] MasterUUTLogResults = new double[10];
            int deviationIndex = 0;
            var valueLog = Math.Log10(value);

            for (int i = 0; i < MasterUUT.Length - 1; i++)
            {
                MasterUUTLogResults[i] = Math.Log10(MasterUUT[i]);
                if (valueLog > MasterUUTLogResults[i] && valueLog < MasterUUTLogResults[i + 1])
                {
                    deviationIndex = i;
                }
            }
            double Error = Deviation[deviationIndex] + (Deviation[deviationIndex + 1] - Deviation[deviationIndex]) / (MasterUUTLogResults[deviationIndex + 1] - MasterUUTLogResults[deviationIndex]) * (valueLog - MasterUUTLogResults[deviationIndex]);


            return value * (1 - (Error / 100));
        }
        public Tuple<double, ResultStatus> CalcCalibrationWithDewPointDeviation(double value)
        {
            // run this function twice, 1 with Dew and 1 with dry temp. (Pdew/ Pdry)*100
            double Value = value;
            double P = 0;


            if (Value >= 0.01 && Value <= 100)
            {
                // liquid
                P = Math.Exp(16.635794 - 6096.9385 / (Value + 273.15) - 0.02711193 * (Value + 273.15) + 0.00001673952 * Math.Pow(Value + 273.15, 2) + 2.433502 * Math.Log(Math.E, (Value + 273.15)));
            }
            else if (Value < 0.01 && Value > -100)
            {
                P = Math.Exp(24.7219 - 6024.5282 / (Value + 273.15) + 0.010613868 * (Value + 273.15) - 0.000013198825 * Math.Pow(Value + 273.15, 2) - 0.49382577 * Math.Log(Math.E, (Value + 273.15)));
            }
            else
            {
                return new Tuple<double, ResultStatus>(P, ResultStatus.WrongValue);
            }

            return new Tuple<double, ResultStatus>(P, ResultStatus.OK);
        }
        public Tuple<double, ResultStatus> CalcResistentce2TemperatureConvertionITS90(string masterID, double value)
        {

            // TODO From DB - Not exit need to add the parameters nofar
            double A4 = -0.0188349;
            double B4 = 0.00064590173677;
            double C7 = 0.00022327774;
            double B7 = -0.00032928408;
            double A7 = -0.01943119;
            double RTP = 100.0018614;

            if (RTP == 0)
                return new Tuple<double, ResultStatus>(0, ResultStatus.WrongValue);

            var W = Math.Abs(value / RTP);
            double dW;

            if (W <= 1)
            {
                dW = (A4 + B4 * Math.Log(W, Math.E)) * (W - 1);
                double x = (Math.Pow((W - dW), 0.1666666666666667) - 0.65) / 0.35;
                //x = (double)(Math.Pow(W - dW, (1 / 6)) - 0.65) / 0.35;
                var res = 0.183324722 + 0.240975303 * x + 0.209108771 * Math.Pow(x, 2) + 0.190439972 * Math.Pow(x, 3)
                    + 0.142648498 * Math.Pow(x, 4) + 0.077993465 * Math.Pow(x, 5) + 0.012475611 * Math.Pow(x, 6)
                    - 0.032267127 * Math.Pow(x, 7) - 0.075291522 * Math.Pow(x, 8) - 0.056470670 * Math.Pow(x, 9)
                    + 0.076201285 * Math.Pow(x, 10) + 0.123893204 * Math.Pow(x, 11) - 0.029201193 * Math.Pow(x, 12)
                    - 0.091173542 * Math.Pow(x, 13) + 0.001317696 * Math.Pow(x, 14) + 0.026025526 * Math.Pow(x, 15);
                return new Tuple<double, ResultStatus>(273.16 * res - 273.15, ResultStatus.OK);
            }
            else
            {
                dW = B7 * Math.Pow(W - 1, 2) + C7 * Math.Pow(W - 1, 3) + A7 * Math.Pow(W - 1, 1);
                var x = (W - dW - 2.64) / 1.64;
                return new Tuple<double, ResultStatus>(439.932854 + 472.418020 * x + 37.684494 * Math.Pow(x, 2) + 7.472018 * Math.Pow(x, 3)
                    + 2.920828 * Math.Pow(x, 4) + 0.005184 * Math.Pow(x, 5) - 0.963864 * Math.Pow(x, 6)
                    - 0.188732 * Math.Pow(x, 7) + 0.191203 * Math.Pow(x, 8) + 0.049025 * Math.Pow(x, 9), ResultStatus.OK);
            }
        }
        public Tuple<double, ResultStatus> CalcConversionUnits(double value, ConversionUnits source, ConversionUnits destination, string ID)
        {
            switch (source)
            {
                case ConversionUnits.Celsius:
                    switch (destination)
                    {
                        case ConversionUnits.Kelvin:
                            return new Tuple<double, ResultStatus>(value + 273.15, ResultStatus.OK);
                        case ConversionUnits.Celsius:
                            return new Tuple<double, ResultStatus>(value, ResultStatus.OK);
                        case ConversionUnits.Fahrenheit:
                            return new Tuple<double, ResultStatus>(value * 1.8 + 32, ResultStatus.OK);
                        case ConversionUnits.Rankine:
                            return new Tuple<double, ResultStatus>((value * 1.8) + 491.67, ResultStatus.OK);
                        default:
                            return new Tuple<double, ResultStatus>(0, ResultStatus.WrongValue);
                    }
                case ConversionUnits.Kelvin:
                    break;
                case ConversionUnits.Fahrenheit:
                    break;
                case ConversionUnits.Rankine:
                    break;
                case ConversionUnits.Millivolt:
                    // TODO from DB return the celsius value from the TC ID.
                    break;
                case ConversionUnits.Ohm:
                    switch (destination)
                    {
                        case ConversionUnits.Celsius:
                            return CalcResistentce2TemperatureConvertionITS90(ID, value);
                    }
                    break;
                default:
                    return new Tuple<double, ResultStatus>(0, ResultStatus.WrongValue);
            }
            return new Tuple<double, ResultStatus>(0, ResultStatus.WrongValue);
        }

        #endregion

        #region Private Methods
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

            var extrimTempMinTemperatureMinHumidity = c.OrderBy(cv => (int)cv.HumidityValue / 5 * 5).ThenBy(cv => cv.TemperatureValue).FirstOrDefault();
            var extrimTempMaxTemperatureMinHumidity = c.OrderBy(cv => (int)cv.HumidityValue / 5 * 5).ThenByDescending(cv => cv.TemperatureValue).FirstOrDefault();
            var extrimTempMinTemperatureMaxHumidity = c.OrderByDescending(cv => (int)cv.HumidityValue / 5 * 5).ThenBy(cv => cv.TemperatureValue).FirstOrDefault();
            var extrimTempMaxTemperatureMaxHumidity = c.OrderByDescending(cv => (int)cv.HumidityValue / 5 * 5).ThenByDescending(cv => cv.TemperatureValue).FirstOrDefault();

            double w1eh = ((double)c.Max(cv => cv.TemperatureValue) - (double)extrimTempMinTemperatureMinHumidity.TemperatureValue) / (((double)c.Max(cv => cv.TemperatureValue)) - ((double)c.Min(cv => cv.TemperatureValue)));
            double w2eh = ((double)extrimTempMaxTemperatureMinHumidity.TemperatureValue - ((double)c.Min(cv => cv.TemperatureValue))) / (((double)c.Max(cv => cv.TemperatureValue)) - ((double)c.Min(cv => cv.TemperatureValue)));
            double w3eh = ((double)c.Max(cv => cv.TemperatureValue) - (double)extrimTempMinTemperatureMaxHumidity.TemperatureValue) / (((double)c.Max(cv => cv.TemperatureValue)) - ((double)c.Min(cv => cv.TemperatureValue)));
            double w4eh = ((double)c.Max(cv => cv.TemperatureValue) - (double)extrimTempMaxTemperatureMaxHumidity.TemperatureValue) / (((double)c.Max(cv => cv.TemperatureValue)) - ((double)c.Min(cv => cv.TemperatureValue)));


            var extrimHumMinTemperatureMinHumidity = c.OrderBy(cv => (int)cv.TemperatureValue).ThenBy(cv => ((int)cv.HumidityValue / 5) * 5).FirstOrDefault();
            var extrimHumMaxTemperatureMinHumidity = c.OrderBy(cv => (int)cv.TemperatureValue).ThenByDescending(cv => ((int)cv.HumidityValue / 5) * 5).FirstOrDefault();
            var extrimHumMinTemperatureMaxHumidity = c.OrderByDescending(cv => (int)cv.TemperatureValue).ThenBy(cv => ((int)cv.HumidityValue / 5) * 5).FirstOrDefault();
            var extrimHumMaxTemperatureMaxHumidity = c.OrderByDescending(cv => (int)cv.TemperatureValue).ThenByDescending(cv => ((int)cv.HumidityValue / 5) * 5).FirstOrDefault();


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

        public double CalcProducerDedails(double Value, double Resultion, string DeviceModel)
        {
            //Get table according to the Device model
            var FullScalePercent = 0;
            var FullScaleValue = 0;
            var OfReadingPercents = 0;
            var Digit = 0;
            var Constant = 0;

            return (FullScalePercent / 100) * FullScaleValue + (OfReadingPercents / 100) * Value + (Digit * Resultion) + Constant;

        }



        #endregion
    }
}