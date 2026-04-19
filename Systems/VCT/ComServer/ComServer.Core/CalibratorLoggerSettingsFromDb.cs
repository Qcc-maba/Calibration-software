using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Text.RegularExpressions;
using Maba.VCT.ComLayer;
using Maba.VCT.Core.Settings;

namespace Maba.VCT.CommServer.Core
{
    /// <summary>
    /// On ComServer startup, loads logger communication settings assigned to a calibrator from SQL
    /// (dbo.GetLogersConfiguredByCalibrator — same assignments written by dbo.AssignMeasurmentDevicesToCalibrator)
    /// and applies them to the serial <see cref="Tunnel"/> in <see cref="VCTSettings"/> before hardware opens.
    /// </summary>
    public static class CalibratorLoggerSettingsFromDb
    {
        private static string GetConnectionString()
        {
            return ConfigurationManager.ConnectionStrings["KyulanSyncDB"]?.ConnectionString
                ?? ConfigurationManager.ConnectionStrings["REMOTE_DATABASE_URL"]?.ConnectionString;
        }

        private static string GetCalibratorEmail()
        {
            var fromConfig = ConfigurationManager.AppSettings["CalibratorUserEmail"];
            if (!string.IsNullOrWhiteSpace(fromConfig))
            {
                return fromConfig.Trim();
            }

            var fromEnv = Environment.GetEnvironmentVariable("CALIBRATOR_USER_EMAIL");
            return string.IsNullOrWhiteSpace(fromEnv) ? null : fromEnv.Trim();
        }

        private static bool IsExplicitlyDisabled()
        {
            var v = ConfigurationManager.AppSettings["SkipCalibratorLoggerFromDatabase"];
            return string.Equals(v, "true", StringComparison.OrdinalIgnoreCase)
                || string.Equals(v, "1", StringComparison.OrdinalIgnoreCase);
        }

        private static bool IsComProtocol(string protocol)
        {
            if (string.IsNullOrWhiteSpace(protocol))
            {
                return false;
            }

            var p = protocol.Trim();
            return p.Equals("COM", StringComparison.OrdinalIgnoreCase)
                || p.IndexOf("serial", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        private static bool LooksLikeComPort(string details)
        {
            if (string.IsNullOrWhiteSpace(details))
            {
                return false;
            }

            return Regex.IsMatch(details.Trim(), @"^COM\d+$", RegexOptions.IgnoreCase);
        }

        private static int ParseBaudFromConnection(string connection)
        {
            if (string.IsNullOrWhiteSpace(connection))
            {
                return 9600;
            }

            var m = Regex.Match(connection, @"\d+");
            if (!m.Success || !int.TryParse(m.Value, out var baud) || baud <= 0)
            {
                return 9600;
            }

            return baud;
        }

        /// <summary>
        /// If CalibratorUserEmail is set and DB is reachable, updates the first serial tunnel with COM port and baud from DB.
        /// </summary>
        public static void TryApplyToVctSettings(VCTSettings settings)
        {
            if (settings == null || settings.Tunnels == null || settings.Tunnels.Length == 0)
            {
                return;
            }

            if (IsExplicitlyDisabled())
            {
                VCT.Libs.Trace.Tracer.Info("[DB→HW] SkipCalibratorLoggerFromDatabase is set; using VCT.json serial settings only.");
                return;
            }

            var email = GetCalibratorEmail();
            if (string.IsNullOrEmpty(email))
            {
                VCT.Libs.Trace.Tracer.Info("[DB→HW] No CalibratorUserEmail (appSettings or CALIBRATOR_USER_EMAIL); serial from VCT.json only.");
                return;
            }

            var cs = GetConnectionString();
            if (string.IsNullOrEmpty(cs))
            {
                VCT.Libs.Trace.Tracer.Info("[DB→HW] No SQL connection string; cannot load calibrator loggers.");
                return;
            }

            try
            {
                using (var conn = new SqlConnection(cs))
                {
                    conn.Open();

                    int? loggerDeviceId = null;
                    string comPort = null;
                    string protocol = null;

                    using (var cmd = new SqlCommand("dbo.GetLogersConfiguredByCalibrator", conn))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.Add("@LoggedInUserEmail", SqlDbType.NVarChar, 256).Value = email;

                        using (var r = cmd.ExecuteReader())
                        {
                            while (r.Read())
                            {
                                if (r.IsDBNull(r.GetOrdinal("LoggerMeasurementDeviceId")))
                                {
                                    continue;
                                }

                                var id = r.GetInt32(r.GetOrdinal("LoggerMeasurementDeviceId"));
                                var proto = r["CommunicationProtocol"] as string;
                                var details = r["CommunicationDetails"] as string;

                                if (!IsComProtocol(proto) || !LooksLikeComPort(details))
                                {
                                    continue;
                                }

                                loggerDeviceId = id;
                                comPort = details.Trim().ToUpperInvariant();
                                protocol = proto;
                                break;
                            }
                        }
                    }

                    if (loggerDeviceId == null || comPort == null)
                    {
                        VCT.Libs.Trace.Tracer.Info(
                            "[DB→HW] No COM logger in GetLogersConfiguredByCalibrator for {0}; serial from VCT.json.",
                            email);
                        return;
                    }

                    var baud = 9600;
                    using (var cmd2 = new SqlCommand("dbo.GetAllCalibrationDevices", conn))
                    {
                        cmd2.CommandType = CommandType.StoredProcedure;
                        cmd2.Parameters.Add("@CalibrationDeviceId", SqlDbType.Int).Value = loggerDeviceId.Value;

                        using (var r2 = cmd2.ExecuteReader())
                        {
                            if (r2.Read())
                            {
                                var ord = r2.GetOrdinal("Connection");
                                var connectionStr = r2.IsDBNull(ord) ? null : r2.GetString(ord);
                                baud = ParseBaudFromConnection(connectionStr);
                            }
                        }
                    }

                    var tunnel = Array.Find(settings.Tunnels, t => !string.IsNullOrEmpty(t.SerialPortName));
                    if (tunnel == null)
                    {
                        VCT.Libs.Trace.Tracer.Info("[DB→HW] No serial tunnel in VCT.json; cannot apply DB COM settings.");
                        return;
                    }

                    tunnel.SerialPortName = comPort;
                    tunnel.SerialBaudRate = baud;

                    VCT.Libs.Trace.Tracer.Info(
                        "[DB→HW] Applied logger from DB for {0}: protocol={1}, port={2}, baud={3} (GetLogersConfiguredByCalibrator + GetAllCalibrationDevices).",
                        email,
                        protocol,
                        comPort,
                        baud);
                }
            }
            catch (Exception ex)
            {
                VCT.Libs.Trace.Tracer.Info("[DB→HW] Failed to load/apply calibrator logger settings: {0}", ex.Message);
            }
        }
    }
}
