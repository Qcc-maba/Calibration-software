using System;
using System.Diagnostics.CodeAnalysis;
using System.IO;
using System.ServiceProcess;
using System.Data;
using System.Data.SqlClient;
using System.Configuration;
using System.Text;

namespace Maba.VCT.CommServer.Hosts.ConsoleHost
{
    /// <summary>Writes to two TextWriters simultaneously (e.g. Console + file).</summary>
    [ExcludeFromCodeCoverage]
    class MultiWriter : TextWriter
    {
        private readonly TextWriter _a, _b;
        public MultiWriter(TextWriter a, TextWriter b) { _a = a; _b = b; }
        public override System.Text.Encoding Encoding => _a.Encoding;
        public override void Write(char value) { _a.Write(value); _b.Write(value); }
        public override void WriteLine(string value) { _a.WriteLine(value); _b.WriteLine(value); }
        public override void Flush() { _a.Flush(); _b.Flush(); }
    }

    [ExcludeFromCodeCoverage]
    class Program
    {
        /// <summary>Sets up logging to server.log file. In console mode, tees to both console and file.
        /// In service mode, writes only to file since there is no console.</summary>
        private static StreamWriter _logWriter;

        internal static void SetupLogging()
        {
            // Avoid double-init (Main calls this, then OnStart calls it again)
            if (_logWriter != null)
                return;

            try
            {
                // Try to write to ../logs/ folder (installed layout), fallback to base directory
                var baseDir = AppDomain.CurrentDomain.BaseDirectory;
                var logsDir = Path.Combine(baseDir, "..", "logs");
                try { Directory.CreateDirectory(logsDir); }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine("[SetupLogging] Create logs dir failed, using base: " + ex.Message);
                    logsDir = baseDir;
                }
                var logPath = Path.Combine(logsDir, "server.log");
                _logWriter = new StreamWriter(logPath, append: true, System.Text.Encoding.UTF8) { AutoFlush = true };

                // Write a session separator
                _logWriter.WriteLine();
                _logWriter.WriteLine($"===== SERVER SESSION STARTED {DateTime.Now:yyyy-MM-dd HH:mm:ss} =====");
                _logWriter.WriteLine();

                if (Environment.UserInteractive)
                {
                    // Console mode: tee to both console and file
                    Console.SetOut(new MultiWriter(Console.Out, _logWriter));
                }
                else
                {
                    // Service mode: write only to file (no console available)
                    Console.SetOut(_logWriter);
                }

                VCT.Libs.Trace.Tracer.CurrentTracer.OutputStream = Console.Out;
            }
            catch (Exception ex)
            {
                // Write to Windows Event Log as fallback so we know logging failed
                try
                {
                    System.Diagnostics.EventLog.WriteEntry("MabaCalibrationServer",
                        $"SetupLogging failed: {ex.GetType().Name}: {ex.Message}",
                        System.Diagnostics.EventLogEntryType.Warning);
                }
                catch (Exception logEx)
                {
                    System.Diagnostics.Debug.WriteLine("[SetupLogging] EventLog fallback failed: " + logEx.Message);
                }
            }
        }

        [MTAThread]
        /// <summary>
        /// Writes one line per fatal event to crash.log next to the executable.
        ///
        /// The server has died silently several times: the console output simply stops mid-line,
        /// stderr is empty, and the process is gone. That is what an exception escaping a
        /// thread-pool thread looks like - nothing in the .NET Framework prints it for you, and
        /// the WebSocket paths all run on pool threads. These handlers do not stop the crash;
        /// they make it leave evidence, which is the difference between fixing it and guessing.
        /// </summary>
        private static void LogFatal(string kind, Exception ex, bool isTerminating)
        {
            try
            {
                var path = System.IO.Path.Combine(
                    AppDomain.CurrentDomain.BaseDirectory ?? ".", "crash.log");
                var text = string.Format(
                    "{0:yyyy-MM-dd HH:mm:ss.fff}  {1}  terminating={2}{3}{4}{5}{6}",
                    DateTime.Now, kind, isTerminating, Environment.NewLine,
                    ex == null ? "(no exception object)" : ex.ToString(),
                    Environment.NewLine, new string('-', 78) + Environment.NewLine);

                System.IO.File.AppendAllText(path, text);
                Console.WriteLine("[FATAL] {0}: {1}", kind, ex == null ? "(none)" : ex.Message);
                Console.Out.Flush();
            }
            catch
            {
                // a failure while recording a crash must not replace the crash
            }
        }

        private static void InstallCrashHandlers()
        {
            AppDomain.CurrentDomain.UnhandledException += (s, e) =>
                LogFatal("UnhandledException", e.ExceptionObject as Exception, e.IsTerminating);

            // an async void that throws, or a faulted Task nobody awaited, lands here
            System.Threading.Tasks.TaskScheduler.UnobservedTaskException += (s, e) =>
            {
                LogFatal("UnobservedTaskException", e.Exception, false);
                e.SetObserved();   // keep it from escalating to a process kill
            };

            AppDomain.CurrentDomain.ProcessExit += (s, e) =>
            {
                try
                {
                    System.IO.File.AppendAllText(
                        System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory ?? ".", "crash.log"),
                        string.Format("{0:yyyy-MM-dd HH:mm:ss.fff}  ProcessExit (clean shutdown){1}",
                            DateTime.Now, Environment.NewLine));
                }
                catch { }
            };
        }

        static void Main(string[] args)
        {
            InstallCrashHandlers();

            if (args.Length > 0 && args[0].Equals("--test-db", StringComparison.OrdinalIgnoreCase))
            {
                TestDatabaseConnection();
                return;
            }

            if (args.Length > 0 && args[0].Equals("--dump-calibrator-loggers", StringComparison.OrdinalIgnoreCase))
            {
                DumpGetLogersConfiguredByCalibrator(args.Length > 1 ? args[1] : null);
                return;
            }

            // Set up logging first - works in both console and service mode
            SetupLogging();

            if (!Environment.UserInteractive)
            {
                // Running as Windows Service
                ServiceBase.Run(new CalibrationService());
                return;
            }

            // Running as console application (dev / debug)
            VCT.Libs.Trace.Tracer.Info("Maba CommServer Console-Host....");
            VCT.Libs.Trace.Tracer.Info("-".PadRight(40, '-'));

            CommServer.Core.MultiBLCommServer comServer = null;
            try
            {
                #region VCT settings

                var vctSettings = VCT.Core.Settings.VCTSettings.Read();

                if (vctSettings.Tunnels == null || vctSettings.Tunnels.Length == 0
                    || vctSettings.DeviceSettings == null || vctSettings.DeviceSettings.Length == 0)
                {
                    vctSettings = VCT.Core.Settings.VCTSettings.CreateDefaultSettings();
                    vctSettings.Save();
                }

                #endregion

                #region Com server settings

                // Read what is on disk first: CreateDefaultSettings() never carries any Modules, so
                // building from it and saving unconditionally overwrote Settings\ComServerSettings.json
                // on every startup and silently erased any module an operator had added. Defaults are
                // seeded only when the file genuinely lists none.
                var settings = CommServer.Core.Settings.ComServerSettings.Read();

                #region Modules

                if (settings.Modules == null || settings.Modules.Length == 0)
                {
                    settings.Modules = new Core.Module[]
                    {
                        new Core.Module()
                        {
                            AssemblyName = System.IO.Path.GetFileNameWithoutExtension(typeof(BL.HydraDevices.BLCore.Hydra2BLCore).Assembly.ManifestModule.Name),
                            TypeName = typeof(BL.HydraDevices.BLCore.Hydra2BLCore).FullName
                        },
                        new Core.Module()
                        {
                            AssemblyName = System.IO.Path.GetFileNameWithoutExtension(typeof(BL.HydraDevices.BLCore.Datron9100BLCore).Assembly.ManifestModule.Name),
                            TypeName = typeof(BL.HydraDevices.BLCore.Datron9100BLCore).FullName
                        },
                        new Core.Module()
                        {
                            AssemblyName = System.IO.Path.GetFileNameWithoutExtension(typeof(BL.HydraDevices.BLCore.KeysightEdux1002aBLCore).Assembly.ManifestModule.Name),
                            TypeName = typeof(BL.HydraDevices.BLCore.KeysightEdux1002aBLCore).FullName
                        }
                    };

                    settings.Save();
                }

                #endregion

                #endregion

                comServer = new CommServer.Core.MultiBLCommServer();
                var hasTunnels = vctSettings.Tunnels != null && vctSettings.Tunnels.Length > 0;
                comServer.Start(deferHardwareIdentificationUntilEnabled: hasTunnels);

                if (hasTunnels)
                {
                    VCT.Libs.Trace.Tracer.Info(
                        "[STARTUP] Hydra identification is paused until the web app sends WebSocket: CMD:\"Status\", Value:\"Start\" (e.g. after operator confirms device identification).");
                }

                VCT.Libs.Trace.Tracer.Info();
                VCT.Libs.Trace.Tracer.Info("Running as console. Press Enter to stop...");

                if (Console.IsInputRedirected)
                {
                    // No interactive console (stdin/stdout redirected to files or pipes, e.g. headless
                    // log capture): Console.ReadLine() would hit EOF immediately, return null, and shut
                    // the server down. Block instead so the host stays alive; terminate via Ctrl+C / kill.
                    new System.Threading.ManualResetEvent(false).WaitOne();
                }
                else
                {
                    Console.ReadLine();
                }
            }
            catch (Exception e)
            {
                VCT.Libs.Trace.Tracer.Exception("Failed to run CommsServer", e);
                Console.WriteLine("Press Any key to exit....");
                Console.ReadLine();
            }
            finally
            {
                comServer?.Stop();
            }
        }

        private static string GetSqlConnectionString()
        {
            return ConfigurationManager.ConnectionStrings["KyulanSyncDB"]?.ConnectionString
                ?? ConfigurationManager.ConnectionStrings["REMOTE_DATABASE_URL"]?.ConnectionString;
        }

        private static void TestDatabaseConnection()
        {
            try
            {
                string connectionString = GetSqlConnectionString();
                if (string.IsNullOrEmpty(connectionString))
                {
                    Console.WriteLine("ERROR: No SQL connection string. Add KyulanSyncDB or REMOTE_DATABASE_URL under connectionStrings in the .exe.config next to ConsoleHost.");
                    Environment.Exit(1);
                }

                using (SqlConnection connection = new SqlConnection(connectionString))
                {
                    connection.Open();
                    Console.WriteLine("SUCCESS: Database connection established.");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"ERROR: {ex.Message}");
                Environment.Exit(1);
            }
        }

        /// <summary>
        /// Prints every column and row returned by dbo.GetLogersConfiguredByCalibrator (for diagnosing SP output).
        /// Usage: ConsoleHost.exe --dump-calibrator-loggers [email] — email optional if CalibratorUserEmail / CALIBRATOR_USER_EMAIL is set.
        /// </summary>
        private static void DumpGetLogersConfiguredByCalibrator(string emailFromArgs)
        {
            try
            {
                var cs = GetSqlConnectionString();
                if (string.IsNullOrEmpty(cs))
                {
                    Console.WriteLine("ERROR: No SQL connection string (KyulanSyncDB or REMOTE_DATABASE_URL).");
                    Environment.Exit(1);
                }

                var email = emailFromArgs?.Trim();
                if (string.IsNullOrEmpty(email))
                {
                    email = ConfigurationManager.AppSettings["CalibratorUserEmail"]?.Trim();
                }

                if (string.IsNullOrEmpty(email))
                {
                    email = Environment.GetEnvironmentVariable("CALIBRATOR_USER_EMAIL")?.Trim();
                }

                if (string.IsNullOrEmpty(email))
                {
                    Console.WriteLine("Usage: ConsoleHost.exe --dump-calibrator-loggers user@example.com");
                    Console.WriteLine("Or set CalibratorUserEmail in .config appSettings, or env CALIBRATOR_USER_EMAIL.");
                    Environment.Exit(1);
                }

                Console.OutputEncoding = Encoding.UTF8;
                Console.WriteLine("dbo.GetLogersConfiguredByCalibrator @LoggedInUserEmail = " + email);
                Console.WriteLine(new string('=', 80));

                using (var conn = new SqlConnection(cs))
                {
                    conn.Open();
                    using (var cmd = new SqlCommand("dbo.GetLogersConfiguredByCalibrator", conn))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.Add("@LoggedInUserEmail", SqlDbType.NVarChar, 256).Value = email;

                        using (var r = cmd.ExecuteReader())
                        {
                            if (!r.HasRows)
                            {
                                Console.WriteLine("(no rows)");
                                return;
                            }

                            var n = r.FieldCount;
                            var headers = new string[n];
                            for (var i = 0; i < n; i++)
                            {
                                headers[i] = r.GetName(i) ?? ("Col" + i);
                            }

                            Console.WriteLine(string.Join(" | ", headers));
                            Console.WriteLine(new string('-', 80));

                            var row = 0;
                            while (r.Read())
                            {
                                row++;
                                var cells = new string[n];
                                for (var i = 0; i < n; i++)
                                {
                                    cells[i] = r.IsDBNull(i) ? "(null)" : Convert.ToString(r.GetValue(i), System.Globalization.CultureInfo.InvariantCulture) ?? "";
                                }

                                Console.WriteLine(string.Join(" | ", cells));
                            }

                            Console.WriteLine(new string('-', 80));
                            Console.WriteLine("Total rows: " + row);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("ERROR: " + ex.Message);
                Environment.Exit(1);
            }
        }
    }
}
