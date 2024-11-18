using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.JsonHelpersLibrary
{
    public static class FileReadWrite
    {
        public static T Read<T>(string path, string filename) where T : class
        {
            try
            {
                var filefullpath = Path.Combine(path, filename);

                using (var st = new FileStream(filefullpath, FileMode.Open, FileAccess.Read))
                {
                    using (var txtReader = new StreamReader(st))
                    {
                        using (var jReader = new Newtonsoft.Json.JsonTextReader(txtReader))
                        {
                            var jSer = Newtonsoft.Json.JsonSerializer.Create();

                            return jSer.Deserialize<T>(jReader);

                        }
                    }
                }
            }
            catch
            { }

            return null;
        }

        public static bool Write<T>(string path, string filename, object obj)
        {
            try
            {
                var filefullpath = Path.Combine(path, filename);

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
    }
}
