using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.JsonHelpersLibrary.HierarchyFiles
{
    public static class HierarchyTypeReader
    {
        const string FOLDER_DEMO_SETTINGS = "DemoSettings";
        const string FOLDER_USED_SETTINGS = "UsedSettings";

        public static T ReadTypeContent<T>(string path) where T : class,new()
        {
            var obj = new T();

            //write skeldon
            var currentType = typeof(T);
            Directory.CreateDirectory(Path.Combine(path, FOLDER_DEMO_SETTINGS));
            Directory.CreateDirectory(Path.Combine(path, FOLDER_USED_SETTINGS));

            foreach (var p in currentType.GetProperties(System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance))
            {
                if (p.PropertyType.IsClass)
                {
                    var attrs = p.GetCustomAttributes(typeof(ReaderAttribute), false);
                    var attr = (attrs != null && attrs.Length > 0) ? (ReaderAttribute)attrs[0] : null;

                    var propertyName = attr == null ? p.Name : (attr.Name ?? p.Name);
                    if (attr == null || !attr.Exclude)
                    {
                        //write the default value
                        WriteJsonObject(p.PropertyType, Path.Combine(path, FOLDER_DEMO_SETTINGS), propertyName, p.GetValue(obj));

                        //read the value from file, if any
                        var readValue = ReadObject(p.PropertyType, path, propertyName);
                        p.SetValue(obj, readValue);

                        //write used value as json
                        WriteJsonObject(p.PropertyType, Path.Combine(path, FOLDER_USED_SETTINGS), propertyName, p.GetValue(obj));
                    }
                }
            }

            return obj;
        }

        public static object ReadObject(Type t, string path, string filename, string FolderName = "Settings", bool RecursiveSearchUp = true, bool CreateDefaultIfMissing = true)
        {
            if (!Path.IsPathRooted(path))
            {
                path = Path.Combine(Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location), path);
            }

            object obj = null;
            bool loaded = false;
            while (!loaded)
            {
                try
                {
                    #region json try

                    var searchedFilename_inFolder = Path.Combine(path, FolderName, Path.ChangeExtension(filename, "json"));
                    if (File.Exists(searchedFilename_inFolder))
                    {
                        loaded = DeserializeJsonObject(t, searchedFilename_inFolder, out obj);
                    }

                    if (!loaded)
                    {
                        var searchedFilename = Path.Combine(path, Path.ChangeExtension(filename, "json"));
                        if (File.Exists(searchedFilename))
                        {
                            loaded = DeserializeJsonObject(t, searchedFilename, out obj);
                        }
                    }

                    #endregion

                    #region  try xml

                    if (!loaded)
                    {
                        var searchedXMLFilename_inFolder = Path.Combine(path, FolderName, Path.ChangeExtension(filename, "xml"));
                        if (File.Exists(searchedXMLFilename_inFolder))
                        {
                            loaded = DeserializeXmlObject(t, searchedXMLFilename_inFolder, out obj);
                        }
                    }

                    if (!loaded)
                    {
                        var searchedXMLFilename = Path.Combine(path, Path.ChangeExtension(filename, "xml"));
                        if (File.Exists(searchedXMLFilename))
                        {
                            loaded = DeserializeXmlObject(t, searchedXMLFilename, out obj);
                        }
                    }

                    #endregion

                    if (!loaded)
                    {
                        if (RecursiveSearchUp)
                        {
                            path = Path.GetDirectoryName(path);
                            if (String.IsNullOrEmpty(path))
                            {
                                if (CreateDefaultIfMissing)
                                {
                                    if (t == typeof(string))
                                    {
                                        return "";
                                    }
                                    else
                                    {
                                        obj = Activator.CreateInstance(t);
                                    }
                                }
                                break;
                            }
                        }
                    }
                }
                catch
                {
                    break;
                }
            }

            return obj;
        }

        private static bool DeserializeXmlObject(Type t, string searchedFilename, out object obj)
        {
            try
            {
                var xr = new System.Xml.Serialization.XmlSerializer(t);

                using (var st = new FileStream(searchedFilename, FileMode.Open, FileAccess.Read))
                {
                    obj = xr.Deserialize(st);
                    return true;
                }
            }
            catch
            {
            }

            obj = null;
            return false;
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

        public static bool WriteJsonObject(Type t, string path, string filename, object obj)
        {
            try
            {
                filename = Path.ChangeExtension(filename, "json");
                var fullPath = Path.Combine(path, filename);

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

    }
}
