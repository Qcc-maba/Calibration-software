namespace Maba.VCT.CommServer.Monitor
{
    partial class FormMain
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
            this.label1 = new System.Windows.Forms.Label();
            this.checkBox7EServer = new System.Windows.Forms.CheckBox();
            this.buttonStart7EDeviceSerial = new System.Windows.Forms.Button();
            this.comboBoxVCTSerial = new System.Windows.Forms.ComboBox();
            this.textBoxVCTPort = new System.Windows.Forms.TextBox();
            this.label2 = new System.Windows.Forms.Label();
            this.textBoxDigiPorts = new System.Windows.Forms.TextBox();
            this.comboBoxDigiSerial = new System.Windows.Forms.ComboBox();
            this.checkBoxDigiServer = new System.Windows.Forms.CheckBox();
            this.buttonStartDigiSerial = new System.Windows.Forms.Button();
            this.buttonStartServer = new System.Windows.Forms.Button();
            this.groupBoxDigiSerial = new System.Windows.Forms.GroupBox();
            this.buttonShowMonitorDigi = new System.Windows.Forms.Button();
            this.label4 = new System.Windows.Forms.Label();
            this.groupBox1 = new System.Windows.Forms.GroupBox();
            this.panelLocalVCT = new System.Windows.Forms.Panel();
            this.panel2 = new System.Windows.Forms.Panel();
            this.panel1 = new System.Windows.Forms.Panel();
            this.label3 = new System.Windows.Forms.Label();
            this.groupBoxDevice7ESerial = new System.Windows.Forms.GroupBox();
            this.buttonShowMonitorVCT = new System.Windows.Forms.Button();
            this.groupBoxDigiSerial.SuspendLayout();
            this.groupBox1.SuspendLayout();
            this.panelLocalVCT.SuspendLayout();
            this.panel2.SuspendLayout();
            this.panel1.SuspendLayout();
            this.groupBoxDevice7ESerial.SuspendLayout();
            this.SuspendLayout();
            // 
            // label1
            // 
            this.label1.AutoSize = true;
            this.label1.Location = new System.Drawing.Point(24, 28);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(86, 13);
            this.label1.TabIndex = 10;
            this.label1.Text = "Serial Port Name";
            // 
            // checkBox7EServer
            // 
            this.checkBox7EServer.AutoSize = true;
            this.checkBox7EServer.Checked = true;
            this.checkBox7EServer.CheckState = System.Windows.Forms.CheckState.Checked;
            this.checkBox7EServer.Location = new System.Drawing.Point(13, 24);
            this.checkBox7EServer.Name = "checkBox7EServer";
            this.checkBox7EServer.Size = new System.Drawing.Size(81, 17);
            this.checkBox7EServer.TabIndex = 9;
            this.checkBox7EServer.Text = "VCT Server";
            this.checkBox7EServer.UseVisualStyleBackColor = true;
            // 
            // buttonStart7EDeviceSerial
            // 
            this.buttonStart7EDeviceSerial.Location = new System.Drawing.Point(220, 19);
            this.buttonStart7EDeviceSerial.Name = "buttonStart7EDeviceSerial";
            this.buttonStart7EDeviceSerial.Size = new System.Drawing.Size(51, 23);
            this.buttonStart7EDeviceSerial.TabIndex = 6;
            this.buttonStart7EDeviceSerial.Text = "Start";
            this.buttonStart7EDeviceSerial.UseVisualStyleBackColor = true;
            this.buttonStart7EDeviceSerial.Click += new System.EventHandler(this.buttonStart7EDeviceSerial_Click);
            // 
            // comboBoxVCTSerial
            // 
            this.comboBoxVCTSerial.Enabled = false;
            this.comboBoxVCTSerial.FormattingEnabled = true;
            this.comboBoxVCTSerial.Location = new System.Drawing.Point(154, 22);
            this.comboBoxVCTSerial.Name = "comboBoxVCTSerial";
            this.comboBoxVCTSerial.Size = new System.Drawing.Size(59, 21);
            this.comboBoxVCTSerial.TabIndex = 6;
            // 
            // textBoxVCTPort
            // 
            this.textBoxVCTPort.Location = new System.Drawing.Point(68, 11);
            this.textBoxVCTPort.Name = "textBoxVCTPort";
            this.textBoxVCTPort.Size = new System.Drawing.Size(78, 20);
            this.textBoxVCTPort.TabIndex = 6;
            this.textBoxVCTPort.Text = "3490";
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(24, 35);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(86, 13);
            this.label2.TabIndex = 12;
            this.label2.Text = "Serial Port Name";
            // 
            // textBoxDigiPorts
            // 
            this.textBoxDigiPorts.Location = new System.Drawing.Point(68, 13);
            this.textBoxDigiPorts.Name = "textBoxDigiPorts";
            this.textBoxDigiPorts.Size = new System.Drawing.Size(78, 20);
            this.textBoxDigiPorts.TabIndex = 8;
            this.textBoxDigiPorts.Text = "50000,50050";
            // 
            // comboBoxDigiSerial
            // 
            this.comboBoxDigiSerial.Enabled = false;
            this.comboBoxDigiSerial.FormattingEnabled = true;
            this.comboBoxDigiSerial.Location = new System.Drawing.Point(152, 29);
            this.comboBoxDigiSerial.Name = "comboBoxDigiSerial";
            this.comboBoxDigiSerial.Size = new System.Drawing.Size(61, 21);
            this.comboBoxDigiSerial.TabIndex = 6;
            // 
            // checkBoxDigiServer
            // 
            this.checkBoxDigiServer.AutoSize = true;
            this.checkBoxDigiServer.Location = new System.Drawing.Point(15, 198);
            this.checkBoxDigiServer.Name = "checkBoxDigiServer";
            this.checkBoxDigiServer.Size = new System.Drawing.Size(78, 17);
            this.checkBoxDigiServer.TabIndex = 11;
            this.checkBoxDigiServer.Text = "Digi Server";
            this.checkBoxDigiServer.UseVisualStyleBackColor = true;
            // 
            // buttonStartDigiSerial
            // 
            this.buttonStartDigiSerial.Enabled = false;
            this.buttonStartDigiSerial.Location = new System.Drawing.Point(220, 26);
            this.buttonStartDigiSerial.Name = "buttonStartDigiSerial";
            this.buttonStartDigiSerial.Size = new System.Drawing.Size(49, 23);
            this.buttonStartDigiSerial.TabIndex = 6;
            this.buttonStartDigiSerial.Text = "Start";
            this.buttonStartDigiSerial.UseVisualStyleBackColor = true;
            this.buttonStartDigiSerial.Click += new System.EventHandler(this.buttonStartDigiSerial_Click);
            // 
            // buttonStartServer
            // 
            this.buttonStartServer.Location = new System.Drawing.Point(30, 19);
            this.buttonStartServer.Name = "buttonStartServer";
            this.buttonStartServer.Size = new System.Drawing.Size(104, 23);
            this.buttonStartServer.TabIndex = 11;
            this.buttonStartServer.Text = "Start Server";
            this.buttonStartServer.UseVisualStyleBackColor = true;
            this.buttonStartServer.Click += new System.EventHandler(this.buttonStartServer_Click);
            // 
            // groupBoxDigiSerial
            // 
            this.groupBoxDigiSerial.Controls.Add(this.buttonShowMonitorDigi);
            this.groupBoxDigiSerial.Controls.Add(this.label2);
            this.groupBoxDigiSerial.Controls.Add(this.comboBoxDigiSerial);
            this.groupBoxDigiSerial.Controls.Add(this.buttonStartDigiSerial);
            this.groupBoxDigiSerial.Enabled = false;
            this.groupBoxDigiSerial.Location = new System.Drawing.Point(15, 252);
            this.groupBoxDigiSerial.Name = "groupBoxDigiSerial";
            this.groupBoxDigiSerial.Size = new System.Drawing.Size(290, 104);
            this.groupBoxDigiSerial.TabIndex = 8;
            this.groupBoxDigiSerial.TabStop = false;
            this.groupBoxDigiSerial.Text = "Digi Serial";
            // 
            // buttonShowMonitorDigi
            // 
            this.buttonShowMonitorDigi.Location = new System.Drawing.Point(152, 66);
            this.buttonShowMonitorDigi.Margin = new System.Windows.Forms.Padding(2);
            this.buttonShowMonitorDigi.Name = "buttonShowMonitorDigi";
            this.buttonShowMonitorDigi.Size = new System.Drawing.Size(115, 19);
            this.buttonShowMonitorDigi.TabIndex = 13;
            this.buttonShowMonitorDigi.Text = "Show Monitor";
            this.buttonShowMonitorDigi.UseVisualStyleBackColor = true;
            this.buttonShowMonitorDigi.Click += new System.EventHandler(this.buttonShowMonitorDigi_Click);
            // 
            // label4
            // 
            this.label4.AutoSize = true;
            this.label4.Location = new System.Drawing.Point(10, 15);
            this.label4.Name = "label4";
            this.label4.Size = new System.Drawing.Size(34, 13);
            this.label4.TabIndex = 13;
            this.label4.Text = "Ports:";
            // 
            // groupBox1
            // 
            this.groupBox1.Controls.Add(this.buttonStartServer);
            this.groupBox1.Controls.Add(this.panelLocalVCT);
            this.groupBox1.Location = new System.Drawing.Point(10, 11);
            this.groupBox1.Name = "groupBox1";
            this.groupBox1.Size = new System.Drawing.Size(400, 457);
            this.groupBox1.TabIndex = 10;
            this.groupBox1.TabStop = false;
            // 
            // panelLocalVCT
            // 
            this.panelLocalVCT.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle;
            this.panelLocalVCT.Controls.Add(this.panel2);
            this.panelLocalVCT.Controls.Add(this.panel1);
            this.panelLocalVCT.Controls.Add(this.checkBox7EServer);
            this.panelLocalVCT.Controls.Add(this.groupBoxDigiSerial);
            this.panelLocalVCT.Controls.Add(this.checkBoxDigiServer);
            this.panelLocalVCT.Controls.Add(this.groupBoxDevice7ESerial);
            this.panelLocalVCT.Cursor = System.Windows.Forms.Cursors.Arrow;
            this.panelLocalVCT.Location = new System.Drawing.Point(30, 58);
            this.panelLocalVCT.Name = "panelLocalVCT";
            this.panelLocalVCT.Size = new System.Drawing.Size(334, 375);
            this.panelLocalVCT.TabIndex = 12;
            // 
            // panel2
            // 
            this.panel2.Controls.Add(this.label4);
            this.panel2.Controls.Add(this.textBoxDigiPorts);
            this.panel2.Location = new System.Drawing.Point(103, 186);
            this.panel2.Margin = new System.Windows.Forms.Padding(2);
            this.panel2.Name = "panel2";
            this.panel2.Size = new System.Drawing.Size(157, 44);
            this.panel2.TabIndex = 15;
            // 
            // panel1
            // 
            this.panel1.Controls.Add(this.label3);
            this.panel1.Controls.Add(this.textBoxVCTPort);
            this.panel1.Location = new System.Drawing.Point(103, 11);
            this.panel1.Margin = new System.Windows.Forms.Padding(2);
            this.panel1.Name = "panel1";
            this.panel1.Size = new System.Drawing.Size(157, 44);
            this.panel1.TabIndex = 14;
            // 
            // label3
            // 
            this.label3.AutoSize = true;
            this.label3.Location = new System.Drawing.Point(10, 14);
            this.label3.Name = "label3";
            this.label3.Size = new System.Drawing.Size(34, 13);
            this.label3.TabIndex = 11;
            this.label3.Text = "Ports:";
            // 
            // groupBoxDevice7ESerial
            // 
            this.groupBoxDevice7ESerial.Controls.Add(this.buttonShowMonitorVCT);
            this.groupBoxDevice7ESerial.Controls.Add(this.label1);
            this.groupBoxDevice7ESerial.Controls.Add(this.buttonStart7EDeviceSerial);
            this.groupBoxDevice7ESerial.Controls.Add(this.comboBoxVCTSerial);
            this.groupBoxDevice7ESerial.Enabled = false;
            this.groupBoxDevice7ESerial.Location = new System.Drawing.Point(15, 76);
            this.groupBoxDevice7ESerial.Name = "groupBoxDevice7ESerial";
            this.groupBoxDevice7ESerial.Size = new System.Drawing.Size(290, 94);
            this.groupBoxDevice7ESerial.TabIndex = 13;
            this.groupBoxDevice7ESerial.TabStop = false;
            this.groupBoxDevice7ESerial.Text = "Device 7E Serial";
            // 
            // buttonShowMonitorVCT
            // 
            this.buttonShowMonitorVCT.Location = new System.Drawing.Point(156, 63);
            this.buttonShowMonitorVCT.Margin = new System.Windows.Forms.Padding(2);
            this.buttonShowMonitorVCT.Name = "buttonShowMonitorVCT";
            this.buttonShowMonitorVCT.Size = new System.Drawing.Size(115, 19);
            this.buttonShowMonitorVCT.TabIndex = 12;
            this.buttonShowMonitorVCT.Text = "Show Monitor";
            this.buttonShowMonitorVCT.UseVisualStyleBackColor = true;
            this.buttonShowMonitorVCT.Click += new System.EventHandler(this.buttonShowMonitorVCT_Click);
            // 
            // FormMain
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(430, 478);
            this.Controls.Add(this.groupBox1);
            this.Margin = new System.Windows.Forms.Padding(2);
            this.Name = "FormMain";
            this.Text = "FormMain";
            this.groupBoxDigiSerial.ResumeLayout(false);
            this.groupBoxDigiSerial.PerformLayout();
            this.groupBox1.ResumeLayout(false);
            this.panelLocalVCT.ResumeLayout(false);
            this.panelLocalVCT.PerformLayout();
            this.panel2.ResumeLayout(false);
            this.panel2.PerformLayout();
            this.panel1.ResumeLayout(false);
            this.panel1.PerformLayout();
            this.groupBoxDevice7ESerial.ResumeLayout(false);
            this.groupBoxDevice7ESerial.PerformLayout();
            this.ResumeLayout(false);

        }

        #endregion
        private System.Windows.Forms.Label label1;
        private System.Windows.Forms.CheckBox checkBox7EServer;
        private System.Windows.Forms.Button buttonStart7EDeviceSerial;
        private System.Windows.Forms.ComboBox comboBoxVCTSerial;
        private System.Windows.Forms.TextBox textBoxVCTPort;
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.TextBox textBoxDigiPorts;
        private System.Windows.Forms.ComboBox comboBoxDigiSerial;
        private System.Windows.Forms.CheckBox checkBoxDigiServer;
        private System.Windows.Forms.Button buttonStartDigiSerial;
        private System.Windows.Forms.Button buttonStartServer;
        private System.Windows.Forms.GroupBox groupBoxDigiSerial;
        private System.Windows.Forms.GroupBox groupBox1;
        private System.Windows.Forms.Panel panelLocalVCT;
        private System.Windows.Forms.GroupBox groupBoxDevice7ESerial;
        private System.Windows.Forms.Label label3;
        private System.Windows.Forms.Label label4;
        private System.Windows.Forms.Button buttonShowMonitorVCT;
        private System.Windows.Forms.Button buttonShowMonitorDigi;
        private System.Windows.Forms.Panel panel2;
        private System.Windows.Forms.Panel panel1;
    }
}