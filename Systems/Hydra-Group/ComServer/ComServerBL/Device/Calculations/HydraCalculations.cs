using ComServerBL.Hydra2.DAL.Calibration;
using Maba.VCT.Common;
using Maba.VCT.Common.API.RemoteProtocolService;
using Maba.VCT.Common.Calibration_results;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;
using System;
using System.Collections.Generic;
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

        #endregion

        #region Members

        private readonly CalibrationRepository _repository;
        public CalibrationResults CalibrationResult { get; set; }

        #endregion

        #region Ctor

        public HydraCalculations(CalibrationRepository repository)
        {
            _repository = repository;
            CalibrationResult = new CalibrationResults();
        }

        #endregion

        #region Data Loading (delegates to DAL)

        public Task<bool> Init(List<string> masters)
        {
            return _repository.InitMasters(masters);
        }

        public Task<bool> LoadCorrectionValues(string procedureName, string parameterName, string loggerName)
        {
            return _repository.LoadCorrectionValues(procedureName, parameterName, loggerName);
        }

        public Tuple<double, CalibrationRepository.ResultStatus> CalcDeviationForTemperature(double value, string sensorID)
        {
            return _repository.CalcDeviationForTemperature(value, sensorID);
        }

        #endregion

        #region Process Results

        public void ProcessResults(LogsResponse response, HardwareBL_DeviceType DeviceType)
        {
            Sample s = null;
            Tuple<double, CalibrationRepository.ResultStatus> results = null;
            if (response == null || DeviceType == null || DeviceType.Sensor == null)
            {
                Trace.WriteLine("ProcessResults: response or DeviceType is null");
                return;
            }

            if (response.Measurements == null || response.Measurements.Count == 0)
            {
                Trace.WriteLine("ProcessResults: no measurements");
                return;
            }

            string masterID = DeviceType.Masters?.FirstOrDefault();
            if (string.IsNullOrEmpty(masterID))
            {
                Trace.WriteLine("ProcessResults: no master configured for device");
                return;
            }

            switch (DeviceType.Sensor.MeasureType)
            {
                case SensorType.MeasureTypes.None:
                    break;
                case SensorType.MeasureTypes.TEMP:
                    for (int i = 0; i < response.Measurements.Count; i++)
                    {
                        results = _repository.CalcDeviationForTemperature(response.Measurements[i], masterID);
                        s = new Sample(results.Item1, response.Measurements[i], (int)results.Item2, DeviceType.Channels[i], Sample.Units.Celsius);
                        CalibrationResult.MasterValues.Add(s);
                    }
                    break;
                case SensorType.MeasureTypes.VDC:
                    for (int i = 0; i < response.Measurements.Count; i++)
                    {
                        results = CalcResistanceToTemperatureITS90(masterID, response.Measurements[i]);
                        s = new Sample(results.Item1, response.Measurements[i], (int)results.Item2, DeviceType.Channels[i], Sample.Units.Celsius);
                        CalibrationResult.MasterValues.Add(s);
                    }
                    break;
                case SensorType.MeasureTypes.Resistance:
                    break;
                case SensorType.MeasureTypes.Dew:
                    if (response.Measurements.Count % 2 != 0)
                    {
                        results = _repository.CalcDeviationForTemperature(response.Measurements[response.Measurements.Count - 1], masterID);
                        s = new Sample(results.Item1, response.Measurements[0], (int)results.Item2, DeviceType.Channels[0], Sample.Units.Celsius);
                        CalibrationResult.MasterValues.Add(s);
                    }
                    else
                    {
                        results = _repository.CalcDeviationForTemperature(response.Measurements[response.Measurements.Count - 1], masterID);
                        var Pdry = CalcDewPointDeviation(results.Item1);
                        var PDew = CalcDewPointDeviation(response.Measurements[1]);
                        var HumidityPercent = (PDew.Item1 / Pdry.Item1) * 100;
                        s = new Sample(results.Item1, response.Measurements[0], (int)results.Item2, DeviceType.Channels[0], Sample.Units.Celsius, response.Measurements[1], Sample.Units.Humidity, HumidityPercent);
                        CalibrationResult.MasterValues.Add(s);
                    }
                    break;
                case SensorType.MeasureTypes.Humidity:
                    if (response.Measurements.Count < 2)
                    {
                        Trace.WriteLine("ProcessResults: Humidity requires at least 2 measurements");
                        break;
                    }
                    var temp = _repository.CalcDeviationForTemperature(response.Measurements[0], masterID);
                    var hum = _repository.CalcDeviationForTemperatureAndHumidity(temp.Item1, response.Measurements[1], masterID);
                    s = new Sample(temp.Item1, response.Measurements[0], (int)temp.Item2, DeviceType.Channels[0], Sample.Units.Celsius, hum.Item1, Sample.Units.Humidity, double.NaN);
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

            Trace.WriteLine(string.Format("Number of samples received: {0}", CalibrationResult.MasterValues.Count));
        }

        #endregion

        #region Pure Calculations (no DB dependency)

        public Tuple<double, CalibrationRepository.ResultStatus> CalcDewPointDeviation(double value)
        {
            double P = 0;

            if (value >= 0.01 && value <= 100)
            {
                P = Math.Exp(16.635794 - 6096.9385 / (value + 273.15) - 0.02711193 * (value + 273.15) + 0.00001673952 * Math.Pow(value + 273.15, 2) + 2.433502 * Math.Log(Math.E, (value + 273.15)));
            }
            else if (value < 0.01 && value > -100)
            {
                P = Math.Exp(24.7219 - 6024.5282 / (value + 273.15) + 0.010613868 * (value + 273.15) - 0.000013198825 * Math.Pow(value + 273.15, 2) - 0.49382577 * Math.Log(Math.E, (value + 273.15)));
            }
            else
            {
                return new Tuple<double, CalibrationRepository.ResultStatus>(P, CalibrationRepository.ResultStatus.WrongValue);
            }

            return new Tuple<double, CalibrationRepository.ResultStatus>(P, CalibrationRepository.ResultStatus.OK);
        }

        public Tuple<double, CalibrationRepository.ResultStatus> CalcResistanceToTemperatureITS90(string masterID, double value)
        {
            // TODO: load parameters from DB via repository
            double A4 = -0.0188349;
            double B4 = 0.00064590173677;
            double C7 = 0.00022327774;
            double B7 = -0.00032928408;
            double A7 = -0.01943119;
            double RTP = 100.0018614;

            if (RTP == 0)
                return new Tuple<double, CalibrationRepository.ResultStatus>(0, CalibrationRepository.ResultStatus.WrongValue);

            var W = Math.Abs(value / RTP);
            double dW;

            if (W <= 1)
            {
                dW = (A4 + B4 * Math.Log(W, Math.E)) * (W - 1);
                double x = (Math.Pow((W - dW), 0.1666666666666667) - 0.65) / 0.35;
                var res = 0.183324722 + 0.240975303 * x + 0.209108771 * Math.Pow(x, 2) + 0.190439972 * Math.Pow(x, 3)
                    + 0.142648498 * Math.Pow(x, 4) + 0.077993465 * Math.Pow(x, 5) + 0.012475611 * Math.Pow(x, 6)
                    - 0.032267127 * Math.Pow(x, 7) - 0.075291522 * Math.Pow(x, 8) - 0.056470670 * Math.Pow(x, 9)
                    + 0.076201285 * Math.Pow(x, 10) + 0.123893204 * Math.Pow(x, 11) - 0.029201193 * Math.Pow(x, 12)
                    - 0.091173542 * Math.Pow(x, 13) + 0.001317696 * Math.Pow(x, 14) + 0.026025526 * Math.Pow(x, 15);
                return new Tuple<double, CalibrationRepository.ResultStatus>(273.16 * res - 273.15, CalibrationRepository.ResultStatus.OK);
            }
            else
            {
                dW = B7 * Math.Pow(W - 1, 2) + C7 * Math.Pow(W - 1, 3) + A7 * Math.Pow(W - 1, 1);
                var x = (W - dW - 2.64) / 1.64;
                return new Tuple<double, CalibrationRepository.ResultStatus>(439.932854 + 472.418020 * x + 37.684494 * Math.Pow(x, 2) + 7.472018 * Math.Pow(x, 3)
                    + 2.920828 * Math.Pow(x, 4) + 0.005184 * Math.Pow(x, 5) - 0.963864 * Math.Pow(x, 6)
                    - 0.188732 * Math.Pow(x, 7) + 0.191203 * Math.Pow(x, 8) + 0.049025 * Math.Pow(x, 9), CalibrationRepository.ResultStatus.OK);
            }
        }

        public Tuple<double, CalibrationRepository.ResultStatus> CalcConversionUnits(double value, ConversionUnits source, ConversionUnits destination, string ID)
        {
            switch (source)
            {
                case ConversionUnits.Celsius:
                    switch (destination)
                    {
                        case ConversionUnits.Kelvin:
                            return new Tuple<double, CalibrationRepository.ResultStatus>(value + 273.15, CalibrationRepository.ResultStatus.OK);
                        case ConversionUnits.Celsius:
                            return new Tuple<double, CalibrationRepository.ResultStatus>(value, CalibrationRepository.ResultStatus.OK);
                        case ConversionUnits.Fahrenheit:
                            return new Tuple<double, CalibrationRepository.ResultStatus>(value * 1.8 + 32, CalibrationRepository.ResultStatus.OK);
                        case ConversionUnits.Rankine:
                            return new Tuple<double, CalibrationRepository.ResultStatus>((value * 1.8) + 491.67, CalibrationRepository.ResultStatus.OK);
                        default:
                            return new Tuple<double, CalibrationRepository.ResultStatus>(0, CalibrationRepository.ResultStatus.WrongValue);
                    }
                case ConversionUnits.Ohm:
                    switch (destination)
                    {
                        case ConversionUnits.Celsius:
                            return CalcResistanceToTemperatureITS90(ID, value);
                    }
                    break;
            }
            return new Tuple<double, CalibrationRepository.ResultStatus>(0, CalibrationRepository.ResultStatus.WrongValue);
        }

        #endregion
    }
}
