using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Windows.Forms;

namespace MapToPngConverter
{
    public partial class MainForm : Form
    {
        public MainForm()
        {
            InitializeComponent();
        }

        private void btnBrowseInput_Click(object sender, EventArgs e)
        {
            Folder();

            using (OpenFileDialog openFileDialog = new OpenFileDialog())
            {
                openFileDialog.Filter = "Map Files (*.map)|*.map|All Files (*.*)|*.*";

                if (openFileDialog.ShowDialog() == DialogResult.OK)
                {
                    txtInputFile.Text = openFileDialog.FileName;
                    txtOutputFile.Text = txtInputFile.Text.Replace(".map", ".png");
                }
            }
        }


        // TODO for all the files in the folders.
        private void Folder()
        {
            using (var fbd = new FolderBrowserDialog())
            {
                DialogResult result = fbd.ShowDialog();

                if (result == DialogResult.OK && !string.IsNullOrWhiteSpace(fbd.SelectedPath))
                {
                    var extensions = new List<string> { ".map" };
                    string[] files = Directory.GetFiles(fbd.SelectedPath, "*.*", SearchOption.AllDirectories)
                                        .Where(f => extensions.IndexOf(Path.GetExtension(f)) >= 0).ToArray();

                    foreach (var file in files)
                    {
                        string input = file;
                        string outpot = input.Replace(".map", ".png");
                        ConvertMapToPng(input, outpot);
                    }


                    //string[] files = Directory.GetFiles(fbd.SelectedPath);
                    //string[] folders = Directory.GetDirectories(fbd.SelectedPath);
                    //System.Windows.Forms.MessageBox.Show("Files found: " + files.Length.ToString(), "Message");
                }
            }
        }


        private void btnConvert_Click(object sender, EventArgs e)
        {
            if (string.IsNullOrWhiteSpace(txtInputFile.Text))
            {
                MessageBox.Show("Please select an input file.", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            if (string.IsNullOrWhiteSpace(txtOutputFile.Text))
            {
                MessageBox.Show("Please select an output file.", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            try
            {
                ConvertMapToPng(txtInputFile.Text, txtOutputFile.Text);
                MessageBox.Show("Conversion successful!", "Success", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Error converting file: {ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void ConvertMapToPng(string inputFile, string outputFile)
        {
            byte[] fileBytes = File.ReadAllBytes(inputFile);

            if (IsValidPngFile(fileBytes))
            {
                File.Copy(inputFile, outputFile, true);
                return;
            }

            int pngStartIndex = FindPngStartIndex(fileBytes);
            if (pngStartIndex != -1)
            {
                byte[] pngBytes = new byte[fileBytes.Length - pngStartIndex];
                Array.Copy(fileBytes, pngStartIndex, pngBytes, 0, pngBytes.Length);

                File.WriteAllBytes(outputFile, pngBytes);
            }
            else
            {
                throw new Exception("No PNG data found in the file");
            }
        }

        private bool IsValidPngFile(byte[] fileBytes)
        {
            byte[] pngSignature = new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };

            if (fileBytes.Length < pngSignature.Length)
                return false;

            for (int i = 0; i < pngSignature.Length; i++)
            {
                if (fileBytes[i] != pngSignature[i])
                    return false;
            }
            return true;
        }

        private int FindPngStartIndex(byte[] fileBytes)
        {
            byte[] pngSignature = new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };

            for (int i = 0; i <= fileBytes.Length - pngSignature.Length; i++)
            {
                bool found = true;
                for (int j = 0; j < pngSignature.Length; j++)
                {
                    if (fileBytes[i + j] != pngSignature[j])
                    {
                        found = false;
                        break;
                    }
                }
                if (found)
                    return i;
            }
            return -1;
        }

        private void InitializeComponent()
        {
            this.txtInputFile = new System.Windows.Forms.TextBox();
            this.txtOutputFile = new System.Windows.Forms.TextBox();
            this.btnBrowseInput = new System.Windows.Forms.Button();
            this.btnBrowseOutput = new System.Windows.Forms.Button();
            this.btnConvert = new System.Windows.Forms.Button();
            this.label1 = new System.Windows.Forms.Label();
            this.label2 = new System.Windows.Forms.Label();
            this.SuspendLayout();
            // 
            // txtInputFile
            // 
            this.txtInputFile.Location = new System.Drawing.Point(12, 25);
            this.txtInputFile.Name = "txtInputFile";
            this.txtInputFile.Size = new System.Drawing.Size(310, 20);
            this.txtInputFile.TabIndex = 0;
            // 
            // txtOutputFile
            // 
            this.txtOutputFile.Location = new System.Drawing.Point(12, 64);
            this.txtOutputFile.Name = "txtOutputFile";
            this.txtOutputFile.Size = new System.Drawing.Size(310, 20);
            this.txtOutputFile.TabIndex = 1;
            // 
            // btnBrowseInput
            // 
            this.btnBrowseInput.Location = new System.Drawing.Point(328, 23);
            this.btnBrowseInput.Name = "btnBrowseInput";
            this.btnBrowseInput.Size = new System.Drawing.Size(75, 23);
            this.btnBrowseInput.TabIndex = 2;
            this.btnBrowseInput.Text = "Browse";
            this.btnBrowseInput.UseVisualStyleBackColor = true;
            this.btnBrowseInput.Click += new System.EventHandler(this.btnBrowseInput_Click);
            // 
            // btnBrowseOutput
            // 
            this.btnBrowseOutput.Location = new System.Drawing.Point(328, 62);
            this.btnBrowseOutput.Name = "btnBrowseOutput";
            this.btnBrowseOutput.Size = new System.Drawing.Size(75, 23);
            this.btnBrowseOutput.TabIndex = 3;
            this.btnBrowseOutput.Text = "Browse";
            this.btnBrowseOutput.UseVisualStyleBackColor = true;
            // 
            // btnConvert
            // 
            this.btnConvert.Location = new System.Drawing.Point(161, 90);
            this.btnConvert.Name = "btnConvert";
            this.btnConvert.Size = new System.Drawing.Size(75, 23);
            this.btnConvert.TabIndex = 4;
            this.btnConvert.Text = "Convert";
            this.btnConvert.UseVisualStyleBackColor = true;
            this.btnConvert.Click += new System.EventHandler(this.btnConvert_Click);
            // 
            // label1
            // 
            this.label1.AutoSize = true;
            this.label1.Location = new System.Drawing.Point(12, 9);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(50, 13);
            this.label1.TabIndex = 5;
            this.label1.Text = "Input File";
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(12, 48);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(58, 13);
            this.label2.TabIndex = 6;
            this.label2.Text = "Output File";
            // 
            // MainForm
            // 
            this.ClientSize = new System.Drawing.Size(415, 125);
            this.Controls.Add(this.label2);
            this.Controls.Add(this.label1);
            this.Controls.Add(this.btnConvert);
            this.Controls.Add(this.btnBrowseOutput);
            this.Controls.Add(this.btnBrowseInput);
            this.Controls.Add(this.txtOutputFile);
            this.Controls.Add(this.txtInputFile);
            this.Name = "MainForm";
            this.Text = "Map to PNG Converter";
            this.ResumeLayout(false);
            this.PerformLayout();
        }

        private TextBox txtInputFile;
        private TextBox txtOutputFile;
        private Button btnBrowseInput;
        private Button btnBrowseOutput;
        private Button btnConvert;
        private Label label1;
        private Label label2;

        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
        }
    }
}