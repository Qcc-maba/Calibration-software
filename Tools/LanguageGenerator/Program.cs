using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace LanguageGenerator
{
    static class Program
    {
        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        [STAThread]
        static void Main()
        {
            #region Generate files
            /*
            
            List<Tuple<string, string>> list = new List<Tuple<string, string>>();
            string ln = "en";
            string jsonstr = "{";
            string path = string.Format(@"D:\Projects\cyber-rain\New_ReliProject\LanguageGenerator\{0}.txt", ln);
            jsonstr += System.Environment.NewLine;
            for (int i = 0; i <= 100; i++)
            {
                jsonstr += "Key_" + i.ToString() + ":" + "'" + ln + "^" + i.ToString() + "'";
                if (i != 100)
                {
                    jsonstr += "," + System.Environment.NewLine;
                }
            }

            jsonstr += System.Environment.NewLine + "}";
            var json = JObject.Parse(jsonstr);
            using (var fs = File.Create(path))
            {
                Byte[] info = new UTF8Encoding(true).GetBytes(json.ToString());
                // Add some information to the file.
                fs.Write(info, 0, info.Length);
            }

            */
            #endregion

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new GeneratorForm());
        }
    }
}
