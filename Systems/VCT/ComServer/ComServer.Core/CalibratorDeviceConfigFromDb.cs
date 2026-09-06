using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using Maba.VCT.CommServer.BL.HydraDevices.Settings;

namespace Maba.VCT.CommServer.Core
{
    /// <summary>
    /// On ComServer startup, overrides the per-instrument-family measurement configuration
    /// (<see cref="HardwareBL_Settings"/>: scan rate, interval, channels) with the values the
    /// coordinator saved for this station's masters via <c>dbo.AssignMeasurmentDevicesToCalibrator</c>.
    /// <para>
    /// The selector is each family bucket's local <see cref="HardwareBL_DeviceType.Masters"/> MabaID
    /// (e.g. "21-260") — that is what pins THIS station to a specific physical master, so we read the
    /// DB config of exactly that device (<c>dbo.MeasurementDevices.MabaID</c>) and its assigned
    /// sensors/channels (<c>dbo.GetSensorsConfiguredByCalibrator</c>). The BL then drives the
    /// instrument (RATE / INTVL / FUNC-per-channel) from these values.
    /// </para>
    /// <para>
    /// Fail-open: any missing config, unreachable DB, or unmatched master leaves the local
    /// HydraBL_Settings.json values untouched. Nothing is written back to disk — the override is
    /// in-memory for the running process only.
    /// </para>
    /// Connection note: outbound device links are serial/GPIB only (see <c>Tunnel</c>). Masters whose
    /// DB protocol is IP/LAN (host:port) cannot be dialed by the current com layer; that is logged and
    /// the serial/GPIB tunnel from VCT.json is kept. See <see cref="CalibratorLoggerSettingsFromDb"/>
    /// for the serial COM/baud side.
    /// </summary>
    public static class CalibratorDeviceConfigFromDb
    {
        private static string GetConnectionString()
        {
            return ConfigurationManager.ConnectionStrings["KyulanSyncDB"]?.ConnectionString
                ?? ConfigurationManager.ConnectionStrings["REMOTE_DATABASE_URL"]?.ConnectionString;
        }

        private static string GetCalibratorEmail()
        {
            /*  The signed-in user wins. It arrives from the web app over the WebSocket (see
                CalibratorSession) and is the only source that is correct when two technicians
                share a station. The settings below are the fallback for runs with no UI at all:
                a Windows service, or --dump-calibrator-loggers from the command line. */
            var fromSession = Maba.VCT.Common.CalibratorSession.Email;
            if (!string.IsNullOrWhiteSpace(fromSession))
            {
                return fromSession;
            }

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

        /// <summary>Maps the DB FlowRate free-text ('איטי'/'מהיר', 'slow'/'fast') to the BL rate enum.</summary>
        private static HardwareBL_DeviceType.MeasurementRates? ParseRate(string flowRate)
        {
            if (string.IsNullOrWhiteSpace(flowRate))
            {
                return null;
            }

            var f = flowRate.Trim();
            if (f.IndexOf("מהיר", StringComparison.Ordinal) >= 0
                || f.IndexOf("fast", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return HardwareBL_DeviceType.MeasurementRates.FAST;
            }

            if (f.IndexOf("איטי", StringComparison.Ordinal) >= 0
                || f.IndexOf("slow", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return HardwareBL_DeviceType.MeasurementRates.SLOW;
            }

            return null;
        }

        /// <summary>Parses "0,1,2,..." lists (one per sensor) into a distinct, ordered channel list.</summary>
        private static List<int> ParseChannels(IEnumerable<string> channelLists)
        {
            var set = new SortedSet<int>();
            foreach (var list in channelLists)
            {
                if (string.IsNullOrWhiteSpace(list))
                {
                    continue;
                }

                foreach (var part in list.Split(','))
                {
                    if (int.TryParse(part.Trim(), out var ch))
                    {
                        set.Add(ch);
                    }
                }
            }

            return set.ToList();
        }

        private static bool IsSerialLikeProtocol(string protocol)
        {
            if (string.IsNullOrWhiteSpace(protocol))
            {
                return false;
            }

            var p = protocol.Trim();
            return p.IndexOf("232", StringComparison.Ordinal) >= 0      // RS-232 / RS-232 + LAN
                || p.IndexOf("serial", StringComparison.OrdinalIgnoreCase) >= 0
                || p.IndexOf("COM", StringComparison.OrdinalIgnoreCase) >= 0
                || p.IndexOf("USB", StringComparison.OrdinalIgnoreCase) >= 0;   // USB-serial adapter
        }

        /// <summary>
        /// For every family bucket that names a local master MabaID, replaces its scan rate, interval
        /// and channel set with the coordinator-saved DB config for that master.
        /// </summary>
        public static void TryApplyToHardwareSettings(HardwareBL_Settings settings)
        {
            if (settings == null)
            {
                return;
            }

            if (IsExplicitlyDisabled())
            {
                VCT.Libs.Trace.Tracer.Info("[DB->HW] SkipCalibratorLoggerFromDatabase is set; using HydraBL_Settings.json only.");
                return;
            }

            var email = GetCalibratorEmail();
            if (string.IsNullOrEmpty(email))
            {
                VCT.Libs.Trace.Tracer.Info("[DB->HW] No CalibratorUserEmail; measurement config from HydraBL_Settings.json only.");
                return;
            }

            var cs = GetConnectionString();
            if (string.IsNullOrEmpty(cs))
            {
                VCT.Libs.Trace.Tracer.Info("[DB->HW] No SQL connection string; cannot load calibrator device config.");
                return;
            }

            // The BL families we can drive, each keyed by the MabaID it declares as its master.
            var buckets = new (string Name, HardwareBL_DeviceType Type)[]
            {
                ("Hydra2", settings.Hydra2type),
                ("Hydra3", settings.Hydra3type),
                ("Agilent", settings.Agilent),
                ("Additel", settings.Additel),
                ("Optidew", settings.Optidew),
                ("TTI22", settings.TTI22),
                ("Instek", settings.Instek),
            };

            try
            {
                using (var conn = new SqlConnection(cs))
                {
                    conn.Open();

                    foreach (var bucket in buckets)
                    {
                        var mabaId = bucket.Type?.Masters?.FirstOrDefault();
                        if (string.IsNullOrWhiteSpace(mabaId))
                        {
                            continue;
                        }

                        ApplyBucketFromDb(conn, email, bucket.Name, mabaId.Trim(), bucket.Type);
                    }
                }
            }
            catch (Exception ex)
            {
                VCT.Libs.Trace.Tracer.Info("[DB->HW] Failed to load/apply calibrator device config: {0}", ex.Message);
            }
        }

        private static void ApplyBucketFromDb(
            SqlConnection conn,
            string email,
            string familyName,
            string mabaId,
            HardwareBL_DeviceType type)
        {
            // 1) Resolve the master (data logger) row + its saved rate/interval/protocol by MabaID.
            int loggerId;
            string model, flowRate, protocol, details;
            int? interval;

            using (var cmd = new SqlCommand(
                @"SELECT TOP 1 ID, Model, FlowRate, Interval, [Connection], IP
                  FROM dbo.MeasurementDevices
                  WHERE MabaID = @MabaID AND MainClassId = 7 AND IsDeleted = 0", conn))
            {
                cmd.Parameters.Add("@MabaID", SqlDbType.NVarChar, 100).Value = mabaId;
                using (var r = cmd.ExecuteReader())
                {
                    if (!r.Read())
                    {
                        VCT.Libs.Trace.Tracer.Info(
                            "[DB->HW] {0}: master MabaID '{1}' not found as a data logger; keeping local settings.",
                            familyName, mabaId);
                        return;
                    }

                    loggerId = r.GetInt32(0);
                    model = r.IsDBNull(1) ? null : r.GetString(1);
                    flowRate = r.IsDBNull(2) ? null : r.GetString(2);
                    interval = r.IsDBNull(3) ? (int?)null : r.GetInt32(3);
                    protocol = r.IsDBNull(4) ? null : r.GetString(4);
                    details = r.IsDBNull(5) ? null : r.GetString(5);
                }
            }

            // 2) Read the sensors + channel lists assigned to that master.
            var channelLists = new List<string>();
            var sensorIds = new List<int>();
            using (var cmd = new SqlCommand("dbo.GetSensorsConfiguredByCalibrator", conn))
            {
                cmd.CommandType = CommandType.StoredProcedure;
                cmd.Parameters.Add("@LoggedInUserEmail", SqlDbType.NVarChar, 100).Value = email;
                cmd.Parameters.Add("@LoggerMeasurementDeviceId", SqlDbType.Int).Value = loggerId;
                using (var r = cmd.ExecuteReader())
                {
                    var idxSensor = r.GetOrdinal("SensorMeasurementDeviceId");
                    var idxChannels = r.GetOrdinal("ChannelList");
                    while (r.Read())
                    {
                        if (!r.IsDBNull(idxSensor))
                        {
                            sensorIds.Add(r.GetInt32(idxSensor));
                        }

                        if (!r.IsDBNull(idxChannels))
                        {
                            channelLists.Add(r.GetString(idxChannels));
                        }
                    }
                }
            }

            // 3) Apply what the DB actually specifies; leave the rest as the local default.
            var rate = ParseRate(flowRate);
            if (rate.HasValue)
            {
                type.MeasurementRate = rate.Value;
            }

            if (interval.HasValue && interval.Value > 0)
            {
                type.Interval = interval.Value;
            }

            var channels = ParseChannels(channelLists);
            if (channels.Count > 0)
            {
                type.Channels = channels;
            }

            // 4) Connection reality check — we can only dial serial/GPIB masters.
            if (!IsSerialLikeProtocol(protocol))
            {
                VCT.Libs.Trace.Tracer.Info(
                    "[DB->HW] {0} (MabaID {1}): DB protocol '{2}' ({3}) is not serial/GPIB; the current com layer cannot dial it — keeping VCT.json tunnel. Measurement config still applied.",
                    familyName, mabaId, protocol ?? "(none)", details ?? "(no details)");
            }

            VCT.Libs.Trace.Tracer.Info(
                "[DB->HW] {0}: applied master '{1}' (id {2}, model {3}) — rate={4}, interval={5}, channels=[{6}], sensors=[{7}], protocol={8}.",
                familyName,
                mabaId,
                loggerId,
                model ?? "?",
                rate.HasValue ? rate.Value.ToString() : type.MeasurementRate + " (local)",
                (interval.HasValue && interval.Value > 0) ? interval.Value.ToString() : type.Interval + " (local)",
                string.Join(",", type.Channels ?? new List<int>()),
                string.Join(",", sensorIds),
                protocol ?? "(none)");
        }
    }
}
