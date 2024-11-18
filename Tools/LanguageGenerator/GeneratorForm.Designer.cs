namespace LanguageGenerator
{
    partial class GeneratorForm
    {
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            this.folderBrowserDialog1 = new System.Windows.Forms.FolderBrowserDialog();
            this.saveFileDialog1 = new System.Windows.Forms.SaveFileDialog();
            this.tabControl1 = new System.Windows.Forms.TabControl();
            this.tabPage1 = new System.Windows.Forms.TabPage();
            this.info = new System.Windows.Forms.Label();
            this.label5 = new System.Windows.Forms.Label();
            this.button5 = new System.Windows.Forms.Button();
            this.checkedListBox3 = new System.Windows.Forms.CheckedListBox();
            this.label6 = new System.Windows.Forms.Label();
            this.button6 = new System.Windows.Forms.Button();
            this.label7 = new System.Windows.Forms.Label();
            this.button7 = new System.Windows.Forms.Button();
            this.textBox3 = new System.Windows.Forms.TextBox();
            this.label8 = new System.Windows.Forms.Label();
            this.tabPage2 = new System.Windows.Forms.TabPage();
            this.groupBox1 = new System.Windows.Forms.GroupBox();
            this.Ignore_rb = new System.Windows.Forms.RadioButton();
            this.insertempty_rb = new System.Windows.Forms.RadioButton();
            this.insertTTT_rb = new System.Windows.Forms.RadioButton();
            this.button3 = new System.Windows.Forms.Button();
            this.button2 = new System.Windows.Forms.Button();
            this.textBox1 = new System.Windows.Forms.TextBox();
            this.label1 = new System.Windows.Forms.Label();
            this.button1 = new System.Windows.Forms.Button();
            this.checkedListBox4 = new System.Windows.Forms.CheckedListBox();
            this.button8 = new System.Windows.Forms.Button();
            this.textBox4 = new System.Windows.Forms.TextBox();
            this.label9 = new System.Windows.Forms.Label();
            this.openFileDialog1 = new System.Windows.Forms.OpenFileDialog();
            this.tabControl1.SuspendLayout();
            this.tabPage1.SuspendLayout();
            this.tabPage2.SuspendLayout();
            this.groupBox1.SuspendLayout();
            this.SuspendLayout();
            // 
            // tabControl1
            // 
            this.tabControl1.Controls.Add(this.tabPage1);
            this.tabControl1.Controls.Add(this.tabPage2);
            this.tabControl1.Cursor = System.Windows.Forms.Cursors.Default;
            this.tabControl1.Location = new System.Drawing.Point(9, 8);
            this.tabControl1.Margin = new System.Windows.Forms.Padding(10);
            this.tabControl1.Name = "tabControl1";
            this.tabControl1.Padding = new System.Drawing.Point(10, 10);
            this.tabControl1.SelectedIndex = 0;
            this.tabControl1.Size = new System.Drawing.Size(525, 489);
            this.tabControl1.TabIndex = 0;
            // 
            // tabPage1
            // 
            this.tabPage1.Controls.Add(this.info);
            this.tabPage1.Controls.Add(this.label5);
            this.tabPage1.Controls.Add(this.button5);
            this.tabPage1.Controls.Add(this.checkedListBox3);
            this.tabPage1.Controls.Add(this.label6);
            this.tabPage1.Controls.Add(this.button6);
            this.tabPage1.Controls.Add(this.label7);
            this.tabPage1.Controls.Add(this.button7);
            this.tabPage1.Controls.Add(this.textBox3);
            this.tabPage1.Controls.Add(this.label8);
            this.tabPage1.Location = new System.Drawing.Point(4, 37);
            this.tabPage1.Name = "tabPage1";
            this.tabPage1.Padding = new System.Windows.Forms.Padding(3);
            this.tabPage1.Size = new System.Drawing.Size(517, 448);
            this.tabPage1.TabIndex = 0;
            this.tabPage1.Text = "Export";
            this.tabPage1.UseVisualStyleBackColor = true;
            // 
            // info
            // 
            this.info.AutoSize = true;
            this.info.Location = new System.Drawing.Point(113, 99);
            this.info.Name = "info";
            this.info.Size = new System.Drawing.Size(0, 14);
            this.info.TabIndex = 10;
            // 
            // label5
            // 
            this.label5.AutoSize = true;
            this.label5.ForeColor = System.Drawing.Color.FromArgb(((int)(((byte)(0)))), ((int)(((byte)(0)))), ((int)(((byte)(192)))));
            this.label5.Location = new System.Drawing.Point(112, 99);
            this.label5.Name = "label5";
            this.label5.Size = new System.Drawing.Size(0, 14);
            this.label5.TabIndex = 9;
            // 
            // button5
            // 
            this.button5.Location = new System.Drawing.Point(341, 75);
            this.button5.Name = "button5";
            this.button5.Size = new System.Drawing.Size(82, 22);
            this.button5.TabIndex = 8;
            this.button5.Text = "2.Process";
            this.button5.UseVisualStyleBackColor = true;
            this.button5.Click += new System.EventHandler(this.ProssesLocation_Click);
            // 
            // checkedListBox3
            // 
            this.checkedListBox3.FormattingEnabled = true;
            this.checkedListBox3.Location = new System.Drawing.Point(31, 128);
            this.checkedListBox3.Name = "checkedListBox3";
            this.checkedListBox3.Size = new System.Drawing.Size(392, 232);
            this.checkedListBox3.TabIndex = 7;
            // 
            // label6
            // 
            this.label6.AutoSize = true;
            this.label6.Location = new System.Drawing.Point(28, 99);
            this.label6.Name = "label6";
            this.label6.Size = new System.Drawing.Size(78, 14);
            this.label6.TabIndex = 6;
            this.label6.Text = "Language List:";
            // 
            // button6
            // 
            this.button6.Location = new System.Drawing.Point(319, 372);
            this.button6.Name = "button6";
            this.button6.Size = new System.Drawing.Size(104, 25);
            this.button6.TabIndex = 5;
            this.button6.Text = "3.Create Excel";
            this.button6.UseVisualStyleBackColor = true;
            this.button6.Click += new System.EventHandler(this.CreateCSV_Click);
            // 
            // label7
            // 
            this.label7.AutoSize = true;
            this.label7.Location = new System.Drawing.Point(25, 85);
            this.label7.Name = "label7";
            this.label7.Size = new System.Drawing.Size(10, 14);
            this.label7.TabIndex = 3;
            this.label7.Text = " ";
            // 
            // button7
            // 
            this.button7.Location = new System.Drawing.Point(341, 45);
            this.button7.Name = "button7";
            this.button7.Size = new System.Drawing.Size(82, 22);
            this.button7.TabIndex = 2;
            this.button7.Text = "1.Browse";
            this.button7.UseVisualStyleBackColor = true;
            this.button7.Click += new System.EventHandler(this.GetfolderTxtFiles_Click);
            // 
            // textBox3
            // 
            this.textBox3.Location = new System.Drawing.Point(95, 46);
            this.textBox3.Name = "textBox3";
            this.textBox3.Size = new System.Drawing.Size(240, 24);
            this.textBox3.TabIndex = 1;
            // 
            // label8
            // 
            this.label8.AutoSize = true;
            this.label8.Location = new System.Drawing.Point(28, 51);
            this.label8.Name = "label8";
            this.label8.Size = new System.Drawing.Size(56, 14);
            this.label8.TabIndex = 0;
            this.label8.Text = "Text Input:";
            // 
            // tabPage2
            // 
            this.tabPage2.Controls.Add(this.groupBox1);
            this.tabPage2.Controls.Add(this.button3);
            this.tabPage2.Controls.Add(this.button2);
            this.tabPage2.Controls.Add(this.textBox1);
            this.tabPage2.Controls.Add(this.label1);
            this.tabPage2.Controls.Add(this.button1);
            this.tabPage2.Controls.Add(this.checkedListBox4);
            this.tabPage2.Controls.Add(this.button8);
            this.tabPage2.Controls.Add(this.textBox4);
            this.tabPage2.Controls.Add(this.label9);
            this.tabPage2.Location = new System.Drawing.Point(4, 37);
            this.tabPage2.Margin = new System.Windows.Forms.Padding(0);
            this.tabPage2.Name = "tabPage2";
            this.tabPage2.Size = new System.Drawing.Size(517, 448);
            this.tabPage2.TabIndex = 1;
            this.tabPage2.Text = "Import";
            this.tabPage2.UseVisualStyleBackColor = true;
            // 
            // groupBox1
            // 
            this.groupBox1.Controls.Add(this.Ignore_rb);
            this.groupBox1.Controls.Add(this.insertempty_rb);
            this.groupBox1.Controls.Add(this.insertTTT_rb);
            this.groupBox1.Location = new System.Drawing.Point(26, 348);
            this.groupBox1.Name = "groupBox1";
            this.groupBox1.Size = new System.Drawing.Size(318, 76);
            this.groupBox1.TabIndex = 12;
            this.groupBox1.TabStop = false;
            this.groupBox1.Text = "Insert When Empty Values";
            // 
            // Ignore_rb
            // 
            this.Ignore_rb.AutoSize = true;
            this.Ignore_rb.Checked = true;
            this.Ignore_rb.Location = new System.Drawing.Point(18, 25);
            this.Ignore_rb.Name = "Ignore_rb";
            this.Ignore_rb.Size = new System.Drawing.Size(55, 18);
            this.Ignore_rb.TabIndex = 11;
            this.Ignore_rb.TabStop = true;
            this.Ignore_rb.Text = "Ignore";
            this.Ignore_rb.UseVisualStyleBackColor = true;
            // 
            // insertempty_rb
            // 
            this.insertempty_rb.AutoSize = true;
            this.insertempty_rb.Location = new System.Drawing.Point(223, 25);
            this.insertempty_rb.Name = "insertempty_rb";
            this.insertempty_rb.Size = new System.Drawing.Size(84, 18);
            this.insertempty_rb.TabIndex = 10;
            this.insertempty_rb.Text = "Insert empty";
            this.insertempty_rb.UseVisualStyleBackColor = true;
            // 
            // insertTTT_rb
            // 
            this.insertTTT_rb.AutoSize = true;
            this.insertTTT_rb.Location = new System.Drawing.Point(110, 25);
            this.insertTTT_rb.Name = "insertTTT_rb";
            this.insertTTT_rb.Size = new System.Drawing.Size(73, 18);
            this.insertTTT_rb.TabIndex = 9;
            this.insertTTT_rb.Text = "Insert TTT";
            this.insertTTT_rb.UseVisualStyleBackColor = true;
            // 
            // button3
            // 
            this.button3.Enabled = false;
            this.button3.Location = new System.Drawing.Point(351, 348);
            this.button3.Name = "button3";
            this.button3.Size = new System.Drawing.Size(91, 24);
            this.button3.TabIndex = 8;
            this.button3.Text = "4.Save Text File";
            this.button3.UseVisualStyleBackColor = true;
            this.button3.Click += new System.EventHandler(this.SaveText_Click_1);
            // 
            // button2
            // 
            this.button2.Location = new System.Drawing.Point(351, 318);
            this.button2.Name = "button2";
            this.button2.Size = new System.Drawing.Size(91, 24);
            this.button2.TabIndex = 7;
            this.button2.Text = "3.Get Folder";
            this.button2.UseVisualStyleBackColor = true;
            this.button2.Click += new System.EventHandler(this.Getfolder_Click);
            // 
            // textBox1
            // 
            this.textBox1.Location = new System.Drawing.Point(104, 318);
            this.textBox1.Name = "textBox1";
            this.textBox1.Size = new System.Drawing.Size(240, 24);
            this.textBox1.TabIndex = 6;
            // 
            // label1
            // 
            this.label1.AutoSize = true;
            this.label1.Location = new System.Drawing.Point(23, 328);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(72, 14);
            this.label1.TabIndex = 5;
            this.label1.Text = "Output Folder";
            // 
            // button1
            // 
            this.button1.Location = new System.Drawing.Point(351, 84);
            this.button1.Name = "button1";
            this.button1.Size = new System.Drawing.Size(91, 24);
            this.button1.TabIndex = 4;
            this.button1.Text = "2.Process";
            this.button1.UseVisualStyleBackColor = true;
            this.button1.Click += new System.EventHandler(this.ProssesFile_Click_1);
            // 
            // checkedListBox4
            // 
            this.checkedListBox4.FormattingEnabled = true;
            this.checkedListBox4.Location = new System.Drawing.Point(23, 84);
            this.checkedListBox4.Name = "checkedListBox4";
            this.checkedListBox4.Size = new System.Drawing.Size(322, 213);
            this.checkedListBox4.TabIndex = 3;
            // 
            // button8
            // 
            this.button8.Location = new System.Drawing.Point(351, 53);
            this.button8.Name = "button8";
            this.button8.Size = new System.Drawing.Size(91, 24);
            this.button8.TabIndex = 2;
            this.button8.Text = "1.Get File";
            this.button8.UseVisualStyleBackColor = true;
            this.button8.Click += new System.EventHandler(this.GetCsvFile_Click);
            // 
            // textBox4
            // 
            this.textBox4.Location = new System.Drawing.Point(104, 53);
            this.textBox4.Name = "textBox4";
            this.textBox4.Size = new System.Drawing.Size(240, 24);
            this.textBox4.TabIndex = 1;
            // 
            // label9
            // 
            this.label9.AutoSize = true;
            this.label9.Location = new System.Drawing.Point(23, 58);
            this.label9.Name = "label9";
            this.label9.Size = new System.Drawing.Size(51, 14);
            this.label9.TabIndex = 0;
            this.label9.Text = "CSV File:";
            // 
            // openFileDialog1
            // 
            this.openFileDialog1.FileName = "openFileDialog1";
            // 
            // Form1
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 14F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.BackColor = System.Drawing.SystemColors.ActiveCaption;
            this.ClientSize = new System.Drawing.Size(543, 507);
            this.Controls.Add(this.tabControl1);
            this.Font = new System.Drawing.Font("Meiryo", 8.25F, System.Drawing.FontStyle.Regular, System.Drawing.GraphicsUnit.Point, ((byte)(177)));
            this.Name = "Form1";
            this.Text = "Language Generator";
            this.tabControl1.ResumeLayout(false);
            this.tabPage1.ResumeLayout(false);
            this.tabPage1.PerformLayout();
            this.tabPage2.ResumeLayout(false);
            this.tabPage2.PerformLayout();
            this.groupBox1.ResumeLayout(false);
            this.groupBox1.PerformLayout();
            this.ResumeLayout(false);

        }

        #endregion

        private System.Windows.Forms.FolderBrowserDialog folderBrowserDialog1;
        private System.Windows.Forms.SaveFileDialog saveFileDialog1;
        private System.Windows.Forms.TabControl tabControl1;
        private System.Windows.Forms.TabPage tabPage1;
        private System.Windows.Forms.Label label5;
        private System.Windows.Forms.Button button5;
        private System.Windows.Forms.CheckedListBox checkedListBox3;
        private System.Windows.Forms.Label label6;
        private System.Windows.Forms.Button button6;
        private System.Windows.Forms.Label label7;
        private System.Windows.Forms.Button button7;
        private System.Windows.Forms.TextBox textBox3;
        private System.Windows.Forms.Label label8;
        private System.Windows.Forms.TabPage tabPage2;
        private System.Windows.Forms.CheckedListBox checkedListBox4;
        private System.Windows.Forms.Button button8;
        private System.Windows.Forms.TextBox textBox4;
        private System.Windows.Forms.Label label9;
        private System.Windows.Forms.Button button1;
        private System.Windows.Forms.Label info;
        private System.Windows.Forms.OpenFileDialog openFileDialog1;
        private System.Windows.Forms.Button button2;
        private System.Windows.Forms.TextBox textBox1;
        private System.Windows.Forms.Label label1;
        private System.Windows.Forms.Button button3;
        private System.Windows.Forms.GroupBox groupBox1;
        private System.Windows.Forms.RadioButton Ignore_rb;
        private System.Windows.Forms.RadioButton insertempty_rb;
        private System.Windows.Forms.RadioButton insertTTT_rb;
    }
}

