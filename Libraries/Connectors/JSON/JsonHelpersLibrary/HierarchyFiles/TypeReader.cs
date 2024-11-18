using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.JsonHelpersLibrary.HierarchyFiles
{
    public static class TypeReader
    {
        const string DEFAULT_EXTENSION = "default";
        const string DEFAULT_Files_Folders = "Settings";


        public static T ReadTypeContent<T>(string folder = null, string settingsfolder = DEFAULT_Files_Folders) where T : class, new()
        {
            var obj = new T();

            if (String.IsNullOrEmpty(folder))
            {
                folder = Path.Combine(
                                        Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location),
                                        DEFAULT_Files_Folders);
            }
            else
            {
                folder = Path.Combine(folder, settingsfolder);
            }

            //create the folder
            Directory.CreateDirectory(folder);
            var defaultFolder = Path.Combine(folder, "Defaults");
            Directory.CreateDirectory(defaultFolder);


            //write skeleton
            var currentType = typeof(T);

            foreach (var p in currentType.GetProperties(System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance))
            {
                if (p.PropertyType.IsClass)
                {
                    if (p.SetMethod == null || !p.SetMethod.IsPublic)
                        continue;

                    var attrs = p.GetCustomAttributes(typeof(ReaderAttribute), false);
                    var attr = (attrs != null && attrs.Length > 0) ? (ReaderAttribute)attrs[0] : null;

                    var propertyName = attr == null ? p.Name : (attr.Name ?? p.Name);
                    if (attr == null || !attr.Exclude)
                    {
                        #region  write the default value

                        var pValue = Activator.CreateInstance(p.PropertyType);
                        if (p.PropertyType.FindInterfaces((t, c) => t == typeof(ISettingsCorrect), null).Length > 0)
                        {
                            ((ISettingsCorrect)pValue).CorrectValues();
                        }

                        foreach (var defaultP in p.PropertyType.GetProperties(System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Instance))
                        {
                            if (defaultP.SetMethod == null
                                || !defaultP.SetMethod.IsPublic
                                || defaultP.PropertyType == typeof(string)
                                || defaultP.PropertyType.IsValueType)
                                continue; 

                            if (defaultP.PropertyType.IsArray)
                            {
                                defaultP.SetValue(pValue, Activator.CreateInstance(defaultP.PropertyType, new object[] { 0 }));
                            }
                            else
                            {
                                if (defaultP.PropertyType.GetConstructor(Type.EmptyTypes) != null)
                                {
                                    defaultP.SetValue(pValue, Activator.CreateInstance(defaultP.PropertyType));
                                }
                            }
                        }

                        WriteJsonObject(p.PropertyType, defaultFolder, $"{propertyName}.{DEFAULT_EXTENSION}.json", pValue);

                        #endregion

                        #region read the value from file, if any

                        var readValue = DeserializeJsonObject(p.PropertyType, folder, $"{propertyName}.json");
                        if (readValue != null)
                        {
                            p.SetValue(obj, readValue);

                            if (p.PropertyType.FindInterfaces((t, c) => t == typeof(ISettingsCorrect), null).Length > 0)
                            {
                                ((ISettingsCorrect)readValue).CorrectValues();
                            }
                        }

                        #endregion
                    }
                }
            }

            return obj;
        }

        private static object DeserializeJsonObject(Type t, string path, string filename)
        {
            try
            {
                var fullpath = Path.Combine(path, filename);

                if (!File.Exists(fullpath))
                {
                    return null;
                }

                using (var st = new FileStream(fullpath, FileMode.Open, FileAccess.Read))
                {
                    using (var txtReader = new StreamReader(st))
                    {
                        using (var jReader = new Newtonsoft.Json.JsonTextReader(txtReader))
                        {
                            var jSer = Newtonsoft.Json.JsonSerializer.Create();
                             
                            return jSer.Deserialize(jReader, t);

                        }
                    }
                }
            }
            catch
            { }
            return null;
        }

        private static bool WriteJsonObject(Type t, string path, string filename, object obj)
        {
            try
            {
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
