using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.VCT.CommServer.Core.Settings
{
    public class ComServerSettings
    {
        #region Properties

        public const string DEFAULT_SETTINGS_FILE_NAME = "ComServerSettings.json";
        public const string DEFAULT_SETTINGS_FOLDER_NAME = "Settings";

        public Module[] Modules { get; set; }
        public Dictionary<string, string>[] IP2Scan { get; set; }

        #endregion

        #region private methods
        private void Save(string fullPath, ComServerSettings obj)
        {
            try
            {
                var Jset = new JsonSerializerSettings()
                {
                    Formatting = Formatting.Indented
                };

                // FileMode.Create, not OpenOrCreate: OpenOrCreate does not truncate, so saving a settings
                // file shorter than the one on disk left the tail of the old content behind and
                // produced a file that is valid JSON followed by garbage.
                using (var st = new FileStream(fullPath, FileMode.Create, FileAccess.Write))
                {
                    using (var txtWriter = new StreamWriter(st))
                    {
                        using (var jWrite = new JsonTextWriter(txtWriter))
                        {
                            var jSer = JsonSerializer.Create(Jset);
                            jSer.Serialize(jWrite, obj);
                        }
                    }
                }
            }
            catch
            {
            }
        }

        #endregion

        #region Public static

        public static ComServerSettings CreateDefaultSettings()
        {
            var defaultSettings = new Core.Settings.ComServerSettings()
            {
                IP2Scan = new Dictionary<string, string>[]
              {
                      new Dictionary<string, string>()
                        { 
                           ["10.3.3.46"] = "21-431",
                           ["10.3.3.47"] = "21-473",
                           ["10.3.3.34"] = "21-474",
                           ["10.3.3.37"] = "21-527",
                           ["10.3.3.32"] = "21-534",
                           ["10.3.3.38"] = "21-549",
                           ["10.3.3.33"] = "21-596",
                           ["10.3.3.35"] = "21-597",
                           ["10.3.3.39"] = "21-649",
                           ["10.3.3.48"] = "21-651",
                           ["10.3.3.36"] = "31-65",
                           ["10.3.3.40"] = "21-999"
                        },
              }
            };
            return defaultSettings;
        }

        public static ComServerSettings Read()
        {
            var defaults = CreateDefaultSettings();

            ComServerSettings _settings = null;
            var filenamePath = GetSettingsFullPath();
            try
            {
                if (File.Exists(filenamePath))
                {
                    var Jset = new Newtonsoft.Json.JsonSerializerSettings()
                    {
                        Formatting = Newtonsoft.Json.Formatting.Indented
                    };
                    using (var st = new FileStream(filenamePath, FileMode.OpenOrCreate, FileAccess.Read))
                    {
                        using (var txtReader = new StreamReader(st))
                        {
                            using (var jReader = new Newtonsoft.Json.JsonTextReader(txtReader))
                            {
                                var jSer = Newtonsoft.Json.JsonSerializer.Create(Jset);
                                _settings = jSer.Deserialize(jReader, typeof(ComServerSettings)) as ComServerSettings;
                            }
                        }
                    }
                }
            }
            catch
            { }

            _settings = _settings ?? CreateDefaultSettings();

            _settings.Modules = AddMissingModules(_settings.Modules, out var added);
            if (added.Count > 0)
                VCT.Libs.Trace.Tracer.Info("[Settings] ComServerSettings.json had no {0} - added (a module this version ships, " +
                                           "missing from a station file kept across the upgrade)", string.Join(", ", added));

            _settings.Save();
            return _settings;
        }

        /// <summary>
        /// BL cores added after stations were first installed. Setup copies ComServerSettings.json with
        /// onlyifdoesntexist, so an upgraded station keeps its old Modules list and a new BL core is never loaded:
        /// its instrument is identified and then claimed by nothing (PR #76 review). Each one listed here is added on
        /// load when it is missing - and saved back, since Read() always saves. Add a core here whenever its module
        /// is added to Installer/assets/Settings/ComServerSettings.json.
        /// </summary>
        public static readonly Module[] ModulesAddedOnUpgrade =
        {
            new Module { AssemblyName = "Maba.VCT.CommServer.BL.HydraDevices", TypeName = "Maba.VCT.CommServer.BL.HydraDevices.BLCore.Daq9600BLCore" },
        };

        /// <summary>
        /// <paramref name="modules"/> plus every <see cref="ModulesAddedOnUpgrade"/> entry it lacks (matched by
        /// TypeName). A file with no modules at all is left alone: that is not an upgraded station but a host with no
        /// settings, and one extra core would not make it work.
        /// </summary>
        public static Module[] AddMissingModules(Module[] modules, out List<string> added)
        {
            added = new List<string>();
            if (modules == null || modules.Length == 0) return modules;

            var list = modules.ToList();
            foreach (var m in ModulesAddedOnUpgrade)
            {
                if (list.Any(x => string.Equals(x?.TypeName, m.TypeName, StringComparison.Ordinal))) continue;
                list.Add(new Module { AssemblyName = m.AssemblyName, TypeName = m.TypeName });
                added.Add(m.TypeName.Substring(m.TypeName.LastIndexOf('.') + 1));
            }
            return list.ToArray();
        }

        public static string GetSettingsFullPath()
        {
            var folder = Path.Combine(
                Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location),
                DEFAULT_SETTINGS_FOLDER_NAME);

            Directory.CreateDirectory(folder);

            return Path.Combine(folder, DEFAULT_SETTINGS_FILE_NAME);
        }

        #endregion

        #region public Methods

        public void Save()
        {
            var fullPath = GetSettingsFullPath();

            Save(fullPath, this);

            Save(Path.ChangeExtension(fullPath, "default.json"), CreateDefaultSettings());
        }

        #endregion
    }
}
