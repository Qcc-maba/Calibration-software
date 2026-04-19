using Maba.DAL.BaseDAL;
using Maba.DAL.BaseDAL.Records;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Data;
using System.Data.Common;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;

namespace ComServerBL.Hydra2.DAL.Calibration
{
    public class CalibrationRepository : BaseConnector
    {
        #region Enums

        public enum ResultStatus : int
        {
            OK = 0,
            LowValue = 1,
            HighValue = 2,
            WrongValue = 3,
        }

        #endregion

        #region Constants

        public const string DEFAULT_STRING_CONNECTION_NAME = "REMOTE_DATABASE_URL";
        public const string DEFAULT_PROCEDURE_NAME = "GetMeasurementDevicesCorrections";
        public const string DEFAULT_PARAMETER_NAME = "@MabaID";
        public const string PARAM_LATEST_VERSION_ONLY = "@GetLatestVersionOnly";

        #endregion

        #region Members

        private readonly ConcurrentDictionary<string, List<CorrectionValues>> _correctionValuesDic = new ConcurrentDictionary<string, List<CorrectionValues>>();

        #endregion

        #region Properties

        public string ProcedureName { get; set; } = DEFAULT_PROCEDURE_NAME;
        public string ParameterName { get; set; } = DEFAULT_PARAMETER_NAME;

        #endregion

        #region Ctor

        public CalibrationRepository()
            : base(DEFAULT_STRING_CONNECTION_NAME)
        {
        }

        public CalibrationRepository(string stringConnectionSectionName)
            : base(stringConnectionSectionName)
        {
        }

        public CalibrationRepository(string stringConnectionSectionName, string procedureName, string parameterName)
            : base(stringConnectionSectionName)
        {
            ProcedureName = procedureName;
            ParameterName = parameterName;
        }

        #endregion

        #region Data Access

        public async Task<List<CorrectionValues>> GetCorrectionValuesAsync(string procedureName, string parameterName, string loggerName)
        {
            try
            {
                var parameter = this.Connector.CreateParameter(parameterName, loggerName);
                var latestVersionParam = this.Connector.CreateParameter(PARAM_LATEST_VERSION_ONLY, 1);

                DbDataReader dbResults = await this.Connector.RunProcedureAsync(
                    procedureName,
                    new IDataParameter[] { parameter, latestVersionParam });

                if (dbResults == null)
                {
                    return null;
                }

                var correctionValues = new List<CorrectionValues>();

                // Log column schema on first read
                var cols = new List<string>();
                for (int c = 0; c < dbResults.FieldCount; c++)
                    cols.Add($"{dbResults.GetName(c)}({dbResults.GetFieldType(c).Name})");
                System.IO.File.AppendAllText("correction.log", DateTime.Now.ToString("HH:mm:ss") + " SP columns: " + string.Join(", ", cols) + Environment.NewLine);

                // Resolve column indices by name
                int colValue1 = dbResults.GetOrdinal("Value1");
                int colDeviation = dbResults.GetOrdinal("Deviation");
                int colValue2 = -1;
                try { colValue2 = dbResults.GetOrdinal("Value2"); } catch { }

                while (dbResults.Read())
                {
                    double temperature = dbResults.IsDBNull(colValue1) ? 0 : Convert.ToDouble(dbResults.GetValue(colValue1));
                    double deviation = dbResults.IsDBNull(colDeviation) ? 0 : Convert.ToDouble(dbResults.GetValue(colDeviation));
                    double humidity = (colValue2 >= 0 && !dbResults.IsDBNull(colValue2)) ? Convert.ToDouble(dbResults.GetValue(colValue2)) : 0;

                    var cv = new CorrectionValues
                    {
                        TemperatureValue = temperature,
                        Deviation = deviation,
                        HumidityValue = humidity
                    };
                    correctionValues.Add(cv);
                }

                return correctionValues;
            }
            catch (Exception e)
            {
                System.IO.File.AppendAllText("correction.log", DateTime.Now.ToString("HH:mm:ss") + $" GetCorrectionValuesAsync ERROR: {e.Message}" + Environment.NewLine);
                Trace.WriteLine($"CalibrationRepository.GetCorrectionValuesAsync error: {e.Message}");
                return null;
            }
        }

        #endregion

        #region Load & Cache

        public async Task<bool> InitMasters(List<string> masters)
        {
            if (masters == null || masters.Count == 0)
            {
                Trace.WriteLine("CalibrationRepository.InitMasters: no masters provided");
                return false;
            }

            var initMsg = $"CalibrationRepository.InitMasters: loading {masters.Count} master(s) from DB (one-time) using SP={ProcedureName}";
            Trace.WriteLine(initMsg);
            System.IO.File.AppendAllText("correction.log", DateTime.Now.ToString("HH:mm:ss") + " " + initMsg + Environment.NewLine);
            bool allLoaded = true;
            foreach (string master in masters)
            {
                var result = await LoadCorrectionValues(ProcedureName, ParameterName, master);
                var masterMsg = $"  Master '{master}' -> {(result ? "loaded OK" : "FAILED")}";
                Trace.WriteLine(masterMsg);
                System.IO.File.AppendAllText("correction.log", DateTime.Now.ToString("HH:mm:ss") + " " + masterMsg + Environment.NewLine);
                if (!result)
                    allLoaded = false;
            }
            var doneMsg = $"CalibrationRepository.InitMasters: done. Cache has {_correctionValuesDic.Count} sensor(s). All loaded={allLoaded}";
            Trace.WriteLine(doneMsg);
            System.IO.File.AppendAllText("correction.log", DateTime.Now.ToString("HH:mm:ss") + " " + doneMsg + Environment.NewLine);
            return allLoaded;
        }

        public async Task<bool> LoadCorrectionValues(string procedureName, string parameterName, string loggerName)
        {
            try
            {
                var correctionValues = await GetCorrectionValuesAsync(procedureName, parameterName, loggerName);

                if (correctionValues == null || correctionValues.Count == 0)
                {
                    System.IO.File.AppendAllText("correction.log", DateTime.Now.ToString("HH:mm:ss") + $" LoadCorrectionValues: '{loggerName}' returned {(correctionValues == null ? "null" : "0 rows")} from SP={procedureName}" + Environment.NewLine);
                    return false;
                }

                bool isTemperatureOnly = correctionValues[0].HumidityValue == 0 &&
                    correctionValues.All(cv => cv.HumidityValue == 0);

                if (!isTemperatureOnly)
                {
                    correctionValues.AddRange(CalculateCornersValues(correctionValues));
                }

                correctionValues = correctionValues.OrderBy(o => o.TemperatureValue).ToList();
                _correctionValuesDic[loggerName] = correctionValues;
                Trace.WriteLine($"CalibrationRepository.LoadCorrectionValues: '{loggerName}' -> {correctionValues.Count} correction points cached (temp range: {correctionValues.First().TemperatureValue} to {correctionValues.Last().TemperatureValue})");
                return true;
            }
            catch (Exception e)
            {
                System.IO.File.AppendAllText("correction.log", DateTime.Now.ToString("HH:mm:ss") + $" LoadCorrectionValues ERROR: {e.Message}" + Environment.NewLine);
                Trace.WriteLine($"CalibrationRepository.LoadCorrectionValues error: {e.Message}");
                return false;
            }
        }

        #endregion

        #region Calibration Calculations

        public Tuple<double, ResultStatus> CalcDeviationForTemperature(double value, string sensorID)
        {
            if (_correctionValuesDic == null || _correctionValuesDic.Count == 0 || !_correctionValuesDic.ContainsKey(sensorID))
            {
                return new Tuple<double, ResultStatus>(9999, ResultStatus.WrongValue);
            }
            var sortedList = _correctionValuesDic[sensorID];
            if (sortedList == null || sortedList.Count == 0)
            {
                return new Tuple<double, ResultStatus>(9999, ResultStatus.WrongValue);
            }

            var minTemp = sortedList[0].TemperatureValue;
            var maxTemp = sortedList[sortedList.Count - 1].TemperatureValue;

            if (value < minTemp)
            {
                return new Tuple<double, ResultStatus>(value - sortedList.First().Deviation, ResultStatus.LowValue);
            }
            if (value > maxTemp)
            {
                return new Tuple<double, ResultStatus>(value - sortedList.Last().Deviation, ResultStatus.HighValue);
            }

            for (int c = 0; c < sortedList.Count - 1; c++)
            {
                if (value == sortedList[c].TemperatureValue)
                {
                    return new Tuple<double, ResultStatus>(value - sortedList[c].Deviation, ResultStatus.OK);
                }
                // Linear interpolation between two surrounding points
                if (sortedList[c].TemperatureValue < value && sortedList[c + 1].TemperatureValue > value)
                {
                    var y31 = sortedList[c + 1].Deviation - sortedList[c].Deviation;
                    var x31 = sortedList[c + 1].TemperatureValue - sortedList[c].TemperatureValue;
                    var x21 = value - sortedList[c].TemperatureValue;
                    var deviation = ((y31 / x31) * x21) + sortedList[c].Deviation;
                    return new Tuple<double, ResultStatus>(value - deviation, ResultStatus.OK);
                }
            }

            if (value == sortedList.Last().TemperatureValue)
            {
                return new Tuple<double, ResultStatus>(sortedList.Last().Deviation, ResultStatus.OK);
            }

            return new Tuple<double, ResultStatus>(9999, ResultStatus.WrongValue);
        }

        public Tuple<double, ResultStatus> CalcDeviationForTemperatureAndHumidity(double temperature, double humidity, string sensorID)
        {
            if (!_correctionValuesDic.ContainsKey(sensorID))
            {
                return new Tuple<double, ResultStatus>(0, ResultStatus.WrongValue);
            }
            var correctionList = _correctionValuesDic[sensorID];

            if (correctionList == null || correctionList.Count == 0)
            {
                return new Tuple<double, ResultStatus>(0, ResultStatus.WrongValue);
            }

            Tuple<int, int, int, double, double, double> bestTriangle = new Tuple<int, int, int, double, double, double>(0, 0, 0, 0, 0, 0);
            double w3min = double.MaxValue;

            for (int i = 0; i < correctionList.Count; i++)
            {
                for (int j = i + 1; j < correctionList.Count; j++)
                {
                    for (int k = j + 1; k < correctionList.Count; k++)
                    {
                        var p1 = correctionList[i];
                        var p2 = correctionList[j];
                        var p3 = correctionList[k];

                        var x1 = ((p1.TemperatureValue * (p3.HumidityValue - p1.HumidityValue)) +
                            (humidity - p1.HumidityValue) * (p3.TemperatureValue - p1.TemperatureValue)) -
                            (temperature * (p3.HumidityValue - p1.HumidityValue));

                        var x2 = ((p2.HumidityValue - p1.HumidityValue) * (p3.TemperatureValue - p1.TemperatureValue)) -
                            ((p2.TemperatureValue - p1.TemperatureValue) * (p3.HumidityValue - p1.HumidityValue));

                        if (x2 == 0) continue;

                        var w1 = x1 / x2;
                        var w2 = (humidity - p1.HumidityValue - (w1 * (p2.HumidityValue - p1.HumidityValue)))
                            / (p3.HumidityValue - p1.HumidityValue);

                        if (w1 < 0 || w2 < 0 || w1 + w2 > 1) continue;

                        var w3 = Math.Sqrt(Math.Pow(p1.HumidityValue - humidity, 2) + Math.Pow(p1.TemperatureValue - temperature, 2))
                               + Math.Sqrt(Math.Pow(p2.HumidityValue - humidity, 2) + Math.Pow(p2.TemperatureValue - temperature, 2))
                               + Math.Sqrt(Math.Pow(p3.HumidityValue - humidity, 2) + Math.Pow(p3.TemperatureValue - temperature, 2));

                        if (w3 < w3min)
                        {
                            w3min = w3;
                            bestTriangle = new Tuple<int, int, int, double, double, double>(i, j, k, w3min, w1, w2);
                        }
                    }
                }
            }

            if (w3min == double.MaxValue)
            {
                return new Tuple<double, ResultStatus>(0, ResultStatus.WrongValue);
            }

            try
            {
                var deviation = correctionList[bestTriangle.Item1].Deviation +
                    (bestTriangle.Item5 * (correctionList[bestTriangle.Item2].Deviation - correctionList[bestTriangle.Item1].Deviation)) +
                    (bestTriangle.Item6 * (correctionList[bestTriangle.Item3].Deviation - correctionList[bestTriangle.Item1].Deviation));
                return new Tuple<double, ResultStatus>(Math.Round(humidity - deviation, 2), ResultStatus.OK);
            }
            catch (Exception e)
            {
                Trace.WriteLine(e.Message);
                return new Tuple<double, ResultStatus>(0, ResultStatus.WrongValue);
            }
        }

        #endregion

        #region Private Methods

        private List<CorrectionValues> CalculateCornersValues(List<CorrectionValues> c)
        {
            double minTemp = c.Min(cv => cv.TemperatureValue);
            double maxTemp = c.Max(cv => cv.TemperatureValue);
            double minHum = c.Min(cv => cv.HumidityValue);
            double maxHum = c.Max(cv => cv.HumidityValue);
            double tempRange = maxTemp - minTemp;
            double humRange = maxHum - minHum;

            var x1 = new CorrectionValues { TemperatureValue = minTemp - 10, HumidityValue = 0 };
            var x2 = new CorrectionValues { TemperatureValue = maxTemp + 10, HumidityValue = 0 };
            var x3 = new CorrectionValues { TemperatureValue = minTemp - 10, HumidityValue = 100 };
            var x4 = new CorrectionValues { TemperatureValue = maxTemp + 10, HumidityValue = 100 };

            var sortedByHumAscTempAsc = c.OrderBy(cv => (int)cv.HumidityValue / 5 * 5).ThenBy(cv => cv.TemperatureValue).ToList();
            var sortedByHumAscTempDesc = c.OrderBy(cv => (int)cv.HumidityValue / 5 * 5).ThenByDescending(cv => cv.TemperatureValue).ToList();
            var sortedByHumDescTempAsc = c.OrderByDescending(cv => (int)cv.HumidityValue / 5 * 5).ThenBy(cv => cv.TemperatureValue).ToList();
            var sortedByHumDescTempDesc = c.OrderByDescending(cv => (int)cv.HumidityValue / 5 * 5).ThenByDescending(cv => cv.TemperatureValue).ToList();

            var extrimTempMinTempMinHum = sortedByHumAscTempAsc[0];
            var extrimTempMaxTempMinHum = sortedByHumAscTempDesc[0];
            var extrimTempMinTempMaxHum = sortedByHumDescTempAsc[0];
            var extrimTempMaxTempMaxHum = sortedByHumDescTempDesc[0];

            double w1eh = (maxTemp - extrimTempMinTempMinHum.TemperatureValue) / tempRange;
            double w2eh = (extrimTempMaxTempMinHum.TemperatureValue - minTemp) / tempRange;
            double w3eh = (maxTemp - extrimTempMinTempMaxHum.TemperatureValue) / tempRange;
            double w4eh = (maxTemp - extrimTempMaxTempMaxHum.TemperatureValue) / tempRange;

            var sortedByTempAscHumAsc = c.OrderBy(cv => (int)cv.TemperatureValue).ThenBy(cv => ((int)cv.HumidityValue / 5) * 5).ToList();
            var sortedByTempAscHumDesc = c.OrderBy(cv => (int)cv.TemperatureValue).ThenByDescending(cv => ((int)cv.HumidityValue / 5) * 5).ToList();
            var sortedByTempDescHumAsc = c.OrderByDescending(cv => (int)cv.TemperatureValue).ThenBy(cv => ((int)cv.HumidityValue / 5) * 5).ToList();
            var sortedByTempDescHumDesc = c.OrderByDescending(cv => (int)cv.TemperatureValue).ThenByDescending(cv => ((int)cv.HumidityValue / 5) * 5).ToList();

            var extrimHumMinTempMinHum = sortedByTempAscHumAsc[0];
            var extrimHumMaxTempMinHum = sortedByTempAscHumDesc[0];
            var extrimHumMinTempMaxHum = sortedByTempDescHumAsc[0];
            var extrimHumMaxTempMaxHum = sortedByTempDescHumDesc[0];

            double w1et = (maxHum - extrimHumMinTempMinHum.HumidityValue) / humRange;
            double w2et = (extrimHumMaxTempMinHum.HumidityValue - minHum) / humRange;
            double w3et = (maxHum - extrimHumMinTempMaxHum.HumidityValue) / humRange;
            double w4et = (extrimHumMaxTempMaxHum.HumidityValue - minHum) / humRange;

            x1.Deviation = ((w1et * extrimHumMinTempMinHum.Deviation) + (w1eh * extrimTempMinTempMinHum.Deviation)) / (w1et + w1eh);
            x2.Deviation = ((w3et * extrimHumMinTempMaxHum.Deviation) + (w2eh * extrimTempMaxTempMinHum.Deviation)) / (w3et + w2eh);
            x3.Deviation = ((w2et * extrimHumMaxTempMinHum.Deviation) + (w3eh * extrimTempMinTempMaxHum.Deviation)) / (w2et + w3eh);
            x4.Deviation = ((w4et * extrimHumMaxTempMaxHum.Deviation) + (w4eh * extrimTempMaxTempMaxHum.Deviation)) / (w4et + w4eh);

            return new List<CorrectionValues> { x1, x2, x3, x4 };
        }

        #endregion
    }
}
