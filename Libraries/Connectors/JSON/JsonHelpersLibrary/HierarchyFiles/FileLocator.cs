using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.JsonHelpersLibrary.HierarchyFiles
{
    public static class FilesLocator
    {
        #region CONSTANTS

        public const string FOLDER_USED_SETTINGS = "UsedSettings";

        #endregion

        #region private static members

        private static Object SyncObject = new Object();
        private static System.Collections.Concurrent.ConcurrentDictionary<string, object> CachedData = new System.Collections.Concurrent.ConcurrentDictionary<string, object>();

        #endregion

        #region public static

        /// <summary>
        /// Setting this property must be the very first line in AppDomain/Application.
        /// In Web application, avoid settings this propery may lead to read/write settings files from/to temporary ASP.NET folder.
        /// In Console and Win Form applications, it can be avoided.
        /// However, good practice it's to set it always.
        /// </summary>
        public static string DefaultFolderLocation { get; set; }

        public static T Read<T>(string FileName = null, bool RecursiveSearchUp = true, bool CreateDefaultIfMissing = true, int maxStep = int.MaxValue, string FolderName = "Settings") where T : class
        {
            return Read<T>(
                DefaultFolderLocation ??  Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location),
                FileName ?? typeof(T).Name,
                RecursiveSearchUp,
                CreateDefaultIfMissing,
                maxStep,
                FolderName);
        }

        public static T Read<T>(string path, string FileName, bool RecursiveSearchUp = true, bool CreateDefaultIfMissing = true, int maxStep = int.MaxValue, string FolderName = "Settings") where T : class
        {
            lock (SyncObject)
            {
                var cachingName = BuildKey<T>(FileName);
                object cachedValue = null;
                if (CachedData.TryGetValue(cachingName, out cachedValue) && cachedValue is T)
                {
                    return cachedValue as T;
                }

                #region fixing path

                if (String.IsNullOrEmpty(path))
                {
                    path = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location);
                }
                else if (!Path.IsPathRooted(path))
                {
                    path = Path.Combine(Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location), path);
                }

                #endregion

                //save original path
                var originalPath = path;

                #region search it over folders up

                var filename = Path.ChangeExtension(FileName, ".json");
                bool loaded = false;
                object value = null;

                while (!loaded && maxStep != 0)
                {
                    var searchedFilename_inFolder = Path.Combine(path, FolderName, filename);
                    if (File.Exists(searchedFilename_inFolder))
                    {
                        if (DeserializeJsonObject(typeof(T), searchedFilename_inFolder, out value))
                        {
                            break;
                        }
                        else
                        {
                            break;
                        }
                    }

                    if (RecursiveSearchUp)
                    {
                        path = Path.GetDirectoryName(path);

                        //if reached the top
                        if (String.IsNullOrEmpty(path))
                        {
                            break;
                        }
                    }
                    else
                    {
                        break;
                    }

                    maxStep--;
                }

                #endregion

                //create if allowed
                if (value == null && CreateDefaultIfMissing)
                {
                    value = Activator.CreateInstance(typeof(T));
                    WriteJsonObject(typeof(T), Path.Combine(originalPath, FolderName), filename, value);
                }

                if (value != null)
                {
                    path = Path.Combine(
                        Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location),
                        FOLDER_USED_SETTINGS);

                    WriteJsonObject(typeof(T), path, filename, value);
                }

                //save in cache
                CachedData.AddOrUpdate(cachingName, value, (k, o) => o);

                return value as T;
            }
        }

        public static bool Write<T>(string path, string FolderName, string FileName, object obj, int Step = 0)
        {
            lock (SyncObject)
            {
                while (Step > 0)
                {
                    path = Path.GetDirectoryName(path);
                    if (String.IsNullOrEmpty(path))
                    {
                        return false;
                    }

                    Step--;
                }

                FileName = Path.ChangeExtension(FileName, ".json");

                return WriteJsonObject(typeof(T), Path.Combine(path, FolderName), FileName, obj);
            }
        }

        public static void ClearCache(string SearchKey = null)
        {
            lock (SyncObject)
            {
                if (String.IsNullOrEmpty(SearchKey))
                {
                    CachedData.Clear();
                }
                else
                {
                    var entries = CachedData.Where(k => k.Key == SearchKey).ToArray();
                    if (entries.Length > 0)
                    {
                        object o;
                        foreach (var e in entries)
                        {
                            CachedData.TryRemove(e.Key, out o);
                        }
                    }
                }
            }
        }

        #endregion

        #region private static

        private static string BuildKey<T>(string FileName)
        {
            return String.Format("{0}<{1}>", FileName, typeof(T).Name);
        }

        private static bool WriteJsonObject(Type t, string path, string filename, object obj)
        {
            try
            {
                //create folder
                Directory.CreateDirectory(path);

                filename = Path.ChangeExtension(filename, "json");
                var fullPath = Path.Combine(path, filename);

                //delete old file (to prevent overlapping)
                if (File.Exists(fullPath))
                {
                    File.Delete(fullPath);
                }
                var jSetting = new Newtonsoft.Json.JsonSerializerSettings()
                {
                    Formatting = Newtonsoft.Json.Formatting.Indented
                };

                using (var st = new FileStream(fullPath, FileMode.OpenOrCreate, FileAccess.Write))
                {
                    using (var txtWriter = new StreamWriter(st))
                    {
                        using (var jWriter = new Newtonsoft.Json.JsonTextWriter(txtWriter))
                        {
                            var jSer = Newtonsoft.Json.JsonSerializer.Create(jSetting);

                            jSer.Serialize(jWriter, obj);
                        }
                    }
                }

                return true;
            }
            catch
            {
                return false;
            }
        }

        private static bool DeserializeJsonObject(Type t, string searchedFilename, out object obj)
        {
            try
            {
                using (var st = new FileStream(searchedFilename, FileMode.Open, FileAccess.Read))
                {
                    using (var txtReader = new StreamReader(st))
                    {
                        using (var jReader = new Newtonsoft.Json.JsonTextReader(txtReader))
                        {
                            var jSer = Newtonsoft.Json.JsonSerializer.Create();

                            obj = jSer.Deserialize(jReader, t);
                            return true;

                        }
                    }
                }
            }
            catch
            { }
            obj = null;
            return false;
        }

        #endregion
    }
}
