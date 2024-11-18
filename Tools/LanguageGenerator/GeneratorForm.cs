using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace LanguageGenerator
{
    public partial class GeneratorForm : Form
    {
        private const string MAIN_LANGUAGE_KEY = "en-US";
        private List<CultureData> CultureDataList = null;
        private List<CultureClass> CultureList = null;

        public GeneratorForm()
        {
            InitializeComponent();
        }

        #region import from txt to csv files

        //1.Get folder
        private void GetfolderTxtFiles_Click(object sender, EventArgs e)
        {
            if (folderBrowserDialog1.ShowDialog() == DialogResult.OK)
            {
                this.textBox3.Text = folderBrowserDialog1.SelectedPath;
            }

        }

        //2.Prosses text files(marke as checked in checkedList)
        //and get the full list of Culture
        private void ProssesLocation_Click(object sender, EventArgs e)
        {
            ClearAll();
            var cultureNamesInfolder = GetcultureNamesInfolder();
            GeneratcultureNames(cultureNamesInfolder);
        }

        //3.bulid the csv
        private void CreateCSV_Click(object sender, EventArgs e)
        {
            Microsoft.Office.Interop.Excel.Workbook wb = null;
            System.Globalization.CultureInfo oldCI = System.Threading.Thread.CurrentThread.CurrentCulture;
            System.Threading.Thread.CurrentThread.CurrentCulture = new System.Globalization.CultureInfo(MAIN_LANGUAGE_KEY);
            Microsoft.Office.Interop.Excel.Application app = new Microsoft.Office.Interop.Excel.Application();
            try
            {
                wb = app.Workbooks.Add(Microsoft.Office.Interop.Excel.XlWBATemplate.xlWBATWorksheet);
            }
            catch
            {

            }

            Microsoft.Office.Interop.Excel.Sheets sheets = wb.Worksheets;
            Microsoft.Office.Interop.Excel.Worksheet sheet = (Microsoft.Office.Interop.Excel.Worksheet)sheets.get_Item(1);
            sheet.Name = "Localize";
            var enCulture = CultureList.Where(u => u.Key == MAIN_LANGUAGE_KEY).FirstOrDefault();
            sheet.Cells[1, 1] = "Key";
            sheet.Cells[1, 2] = enCulture.Name;
            sheet.Cells[2, 2] = enCulture.Key;

            CultureDataList = new List<LanguageGenerator.CultureData>();

            CultureData enCultureKeys = null;
            enCultureKeys = OpenTranslateFile(enCulture);
            #region Get en file
            for (int i = 0; i < enCultureKeys.Keys.Count; i++)
            {
                var key =  enCultureKeys.Keys[i].Key;
                sheet.Cells[3 + i, 1] = key;
                var value = enCultureKeys.Keys[i].Value;
                sheet.Cells[3 + i, 2] = value;
                if (key.StartsWith("SECTION"))
                {
                    sheet.Cells[3 + i,1].Font.Bold = true;
                    if (value.StartsWith("***"))
                    {
                        sheet.Cells[3 + i, 1].Interior.Color = Color.FromArgb(71, 253, 208); 
                    }
                    else
                    {
                        sheet.Cells[3 + i, 1].Interior.Color = Color.FromArgb(149,145, 162); 
                    }
                }
                else
                {
                    sheet.Cells[3 + i, 1].Font.Bold = false;
                   // sheet.Cells[3 + i, 1].Interior.Color = null;  
                }
            }


            #endregion

            #region Get All Selected Language
            var CheckedItems = checkedListBox3.CheckedItems.OfType<CultureClass>().ToList();
            var offset = 3;
            foreach (var item in CheckedItems)
            {
                CultureClass t = item as CultureClass;
                if (t.Key == enCulture.Key)
                    continue;

                sheet.Cells[1, offset] = t.Name;
                sheet.Cells[2, offset] = t.Key;

                var data = OpenTranslateFile(t);
            
                for (int i = 0; i < data.Keys.Count; i++)
                {
                    for (int j = 0; j < enCultureKeys.Keys.Count; j++)
                    {
                        if (enCultureKeys.Keys[j].Key == data.Keys[i].Key)
                        {
                            sheet.Cells[j + 3, offset] = data.Keys[i].Value;
                          
                        }

                    }
                   
                }
                offset++;
            }

            #endregion

            #region write to Excel file

            saveFileDialog1 = new SaveFileDialog();
            saveFileDialog1.Filter = "Excel |*.xlsx";
            saveFileDialog1.Title = "Save an Excel File";
            saveFileDialog1.ShowDialog();


            wb.SaveAs(saveFileDialog1.FileName);
            wb.Close(false);
            app.Quit();
            ShowXls(saveFileDialog1.FileName);
            #endregion
        }

        #endregion

        #region Private function

        public void ShowXls(string xslFilePath)
        {
            if (!System.IO.File.Exists(xslFilePath))
                return;

            Microsoft.Office.Interop.Excel.Application app = new Microsoft.Office.Interop.Excel.Application();
            Microsoft.Office.Interop.Excel.Workbook wb = app.Workbooks.Open(xslFilePath,
              0, false, 5, "", "", false, Microsoft.Office.Interop.Excel.XlPlatform.xlWindows, "",
                 true, false, 0, true, false, false);

            app.Visible = true;
        }

        private void ClearAll()
        {
            CultureList = new List<CultureClass>();
            CultureDataList = new List<CultureData>();
            info.Text = "";
            checkedListBox3.Items.Clear();
            checkedListBox4.Items.Clear();
        }

        private void GeneratcultureNames(List<string> _cultureNamesInfolder)
        {
            bool Contains = false;
            var CultureListInfo = CultureInfo.GetCultures(CultureTypes.AllCultures).Where(u => u.DisplayName != CultureInfo.InvariantCulture.DisplayName);

            foreach (CultureInfo ci in CultureListInfo.OrderBy(u => u.Name))
            {
                var t = new CultureClass() { Key = ci.Name, Name = ci.EnglishName };
                Contains = _cultureNamesInfolder.Contains(t.Key);
                if (Contains)
                {
                    info.Text += string.IsNullOrEmpty(info.Text) ? t.Key : " , " + t.Key;
                }
                checkedListBox3.Items.Add(t, Contains);
                CultureList.Add(t);

            }

        }

        private CultureData OpenTranslateFile(CultureClass c)
        {
            var serializer = new JsonSerializer();
            try
            {
                var fileName = string.Format(this.textBox3.Text + @"\{0}.txt", c.Key);
                if (File.Exists(fileName))
                {
                    string line;
                    using (StreamReader sr = new StreamReader(fileName, Encoding.UTF8, true))
                    {
                        line = sr.ReadToEnd();
                    }


                    //string s = sr.ReadToEnd();
                    return ParseingStrings(c, line);
                }
                else
                {

                    var CultureData = new CultureData() { CultureClass = c, Keys = new List<KeyValuePair>() };
                    CultureDataList.Add(CultureData);
                    return CultureData;
                }

            }
            catch (Exception)
            {

                throw;
            }
        }

        private CultureData ParseingStrings(CultureClass cultureClass, string entries)
        {
            CultureData c = new CultureData();
            c.CultureClass = cultureClass;
            c.Keys = new List<KeyValuePair>();
            JObject obj = JObject.Parse(entries);

            foreach (JToken item in obj.Children())
            {

                var property = item as JProperty;
                KeyValuePair l = new KeyValuePair();
                l.Key = property.Name;
                l.Value = property.Value.ToString();
                c.Keys.Add(l);

            }
            CultureDataList.Add(c);

            return c;
        }

        private List<string> GetcultureNamesInfolder()
        {
            try
            {
                if (string.IsNullOrEmpty(this.textBox3.Text))
                {
                    throw new Exception("folder text is empty");
                }
                List<string> filePaths = new List<string>();

                DirectoryInfo d = new DirectoryInfo(this.textBox3.Text);

                foreach (var file in d.GetFiles("*.txt"))
                {
                    filePaths.Add(file.Name.Substring(0, file.Name.Length - 4));
                }

                return filePaths;

            }
            catch
            {
                throw;
            }

        }


        #endregion

        #region export form csv to txt file

        //1.get file location
        private void GetCsvFile_Click(object sender, EventArgs e)
        {
            OpenFileDialog openFileDialog1 = new OpenFileDialog();
            openFileDialog1.Filter = "Excel |*.xlsx";
            openFileDialog1.Title = "Select a Excel File";

            if (openFileDialog1.ShowDialog() == DialogResult.OK)
            {
                textBox4.Text = openFileDialog1.FileName;
            }
        }

        //2.get the Culture that in the csv
        private void ProssesFile_Click_1(object sender, EventArgs e)
        {
            //Clear all

            ClearAll();
            #region Get csv file
            var xlsFile = this.textBox4.Text;
            if (string.IsNullOrEmpty(this.textBox4.Text))
            {
                throw new Exception("There is no file at all");
            }
            string path = new FileInfo(xlsFile).DirectoryName;
            System.Globalization.CultureInfo oldCI = System.Threading.Thread.CurrentThread.CurrentCulture;
            System.Threading.Thread.CurrentThread.CurrentCulture = new System.Globalization.CultureInfo(MAIN_LANGUAGE_KEY);
            Microsoft.Office.Interop.Excel.Application app = new Microsoft.Office.Interop.Excel.Application();
            Microsoft.Office.Interop.Excel.Workbook wb = app.Workbooks.Open(xlsFile,
             0, false, 5, "", "", false, Microsoft.Office.Interop.Excel.XlPlatform.xlWindows, "",
             true, false, 0, true, false, false);

            Microsoft.Office.Interop.Excel.Sheets sheets = wb.Worksheets;

            Microsoft.Office.Interop.Excel.Worksheet sheet = (Microsoft.Office.Interop.Excel.Worksheet)sheets.get_Item(1);
            List<string> columns = new List<string>();
            columns.Add(MAIN_LANGUAGE_KEY);
            var col = 3;

            string key_line = (sheet.Cells[2, col] as Microsoft.Office.Interop.Excel.Range).Text;
            columns.Add(key_line);
            while (!string.IsNullOrEmpty(key_line) && key_line != " ")
            {
                col++;
                key_line = (sheet.Cells[2, col] as Microsoft.Office.Interop.Excel.Range).Text;
                if (!string.IsNullOrEmpty(key_line) && key_line != " ")
                    columns.Add(key_line);
            }

            CultureDataList = new List<CultureData>();
            GeneratcultureNames(columns.ToList());

            for (int i = 0; i < columns.Count; i++)
            {
                var c = CultureList.Where(u => u.Key == columns[i]).FirstOrDefault();
                if (c != null && !string.IsNullOrEmpty(c.Key) )
                {
                    checkedListBox4.Items.Add(c, true);
                    CultureDataList.Add(new CultureData() { CultureClass = c, Keys = new List<KeyValuePair>() });
                }
            }

            wb.Close(false);
            app.Quit();
            #endregion
            button3.Enabled = true;
        }
        //3.get folder to save txt files
        private void Getfolder_Click(object sender, EventArgs e)
        {
            if (folderBrowserDialog1.ShowDialog() == DialogResult.OK)
            {
                this.textBox1.Text = folderBrowserDialog1.SelectedPath;
            }
        }
        //4.save txt files
        private void SaveText_Click_1(object sender, EventArgs e)
        {
            try
            {
                var xlsFile = this.textBox4.Text;
                if (string.IsNullOrEmpty(this.textBox4.Text))
                {
                    throw new Exception("There is no file at all");
                }
                string path = new FileInfo(xlsFile).DirectoryName;
                System.Globalization.CultureInfo oldCI = System.Threading.Thread.CurrentThread.CurrentCulture;
                System.Threading.Thread.CurrentThread.CurrentCulture = new System.Globalization.CultureInfo(MAIN_LANGUAGE_KEY);
                Microsoft.Office.Interop.Excel.Application app = new Microsoft.Office.Interop.Excel.Application();
                Microsoft.Office.Interop.Excel.Workbook wb = app.Workbooks.Open(xlsFile,
                 0, false, 5, "", "", false, Microsoft.Office.Interop.Excel.XlPlatform.xlWindows, "",
                 true, false, 0, true, false, false);

                Microsoft.Office.Interop.Excel.Sheets sheets = wb.Worksheets;

                Microsoft.Office.Interop.Excel.Worksheet sheet = (Microsoft.Office.Interop.Excel.Worksheet)sheets.get_Item(1);
                var col = 0;
                var enCulture = CultureDataList.Where(u => u.CultureClass.Key == MAIN_LANGUAGE_KEY).FirstOrDefault();
                #region Bulid en Culture.Keys

                {
                    var index = 3;
                    var key = (sheet.Cells[index, 1] as Microsoft.Office.Interop.Excel.Range).Text;
                    var value = (sheet.Cells[index, 2] as Microsoft.Office.Interop.Excel.Range).Text;
                    while (!string.IsNullOrEmpty(key) && key != " ")
                    {
                        enCulture.Keys.Add(new KeyValuePair() { Value = value, Key = key });
                        index++;
                        key = (sheet.Cells[index, 1] as Microsoft.Office.Interop.Excel.Range).Text;
                        value = (sheet.Cells[index, 2] as Microsoft.Office.Interop.Excel.Range).Text;
                    }
                }


                #endregion
                foreach (var item in CultureDataList)
                {
                    if (item.CultureClass.Key == MAIN_LANGUAGE_KEY)
                        continue;
                    var index = 3;
                    while ((index-3) < enCulture.Keys.Count)
                    {
                        string value = (sheet.Cells[index, col + 3] as Microsoft.Office.Interop.Excel.Range).Text;
                        
                        if(string.IsNullOrEmpty(value) || value == " ")
                        {
                            if(insertempty_rb.Checked)
                            {
                                value = string.Empty;
                            }
                            if(insertTTT_rb.Checked)
                            {
                                value = "TTT";
                            }
                            if(Ignore_rb.Checked)
                            {
                                index++;
                                continue;
                            }
                        }
                        item.Keys.Add(new KeyValuePair() { Key = enCulture.Keys[index-3].Key, Value = value });
                        index++;
                    }
                    col++;
                }
                
                wb.Close(false);
                app.Quit();
            }
            catch
            {

            }
            finally
            {
                button3.Enabled = false;
            }


            #region Save file

            var CheckedItems = checkedListBox4.CheckedItems.OfType<CultureClass>().ToList();

            foreach (var item in CheckedItems)
            {
                var c = item as CultureClass;

                var d = CultureDataList.Where(u => u.CultureClass.Key == c.Key).FirstOrDefault();

                using (System.IO.StreamWriter file = new System.IO.StreamWriter(string.Format(@"{0}\{1}.txt", this.textBox1.Text, c.Key), false, Encoding.UTF8))
                {
                    file.WriteLine("{");
                    var count = 0;
                    foreach (var line in d.Keys)
                    {
                        count++;
                        if (count==d.Keys.Count)
                        {
                            if (line.Key.StartsWith("SECTION"))
                            {
                                file.WriteLine(string.Format(@"""{0}"":""{1}""", line.Key, line.Value));
                                break;
                            }
                            else
                            {
                                file.WriteLine(string.Format("\t\t" + @"""{0}"":""{1}""", line.Key, line.Value));
                                break;
                            }
                        }
                        if (line.Key.StartsWith("SECTION"))
                        {
                            file.WriteLine(string.Format(@"""{0}"":""{1}""", line.Key, line.Value));
                        }
                        else
                        {

                            file.WriteLine(string.Format("\t\t"+@"""{0}"":""{1}""", line.Key, line.Value));
                        }

                    }
                    file.WriteLine("}");
                }
            }

            #endregion

           
        }

        #endregion


    }
}
