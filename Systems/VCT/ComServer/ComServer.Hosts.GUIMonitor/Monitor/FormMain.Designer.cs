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
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        private void InitializeComponent()
        {
            this.groupBoxServer = new System.Windows.Forms.GroupBox();
            this.labelPorts = new System.Windows.Forms.Label();
            this.textBoxVCTPort = new System.Windows.Forms.TextBox();
            this.buttonStartServer = new System.Windows.Forms.Button();
            this.groupBoxSerial = new System.Windows.Forms.GroupBox();
            this.labelCom = new System.Windows.Forms.Label();
            this.comboBoxVCTSerial = new System.Windows.Forms.ComboBox();
            this.buttonRefreshPorts = new System.Windows.Forms.Button();
            this.labelBaud = new System.Windows.Forms.Label();
            this.comboBoxBaud = new System.Windows.Forms.ComboBox();
            this.labelHandshake = new System.Windows.Forms.Label();
            this.comboBoxHandshake = new System.Windows.Forms.ComboBox();
            this.buttonStart7EDeviceSerial = new System.Windows.Forms.Button();
            this.buttonShowMonitorVCT = new System.Windows.Forms.Button();
            this.labelStatus = new System.Windows.Forms.Label();
            this.groupBoxServer.SuspendLayout();
            this.groupBoxSerial.SuspendLayout();
            this.SuspendLayout();
            //
            // groupBoxServer
            //
            this.groupBoxServer.Controls.Add(this.labelPorts);
            this.groupBoxServer.Controls.Add(this.textBoxVCTPort);
            this.groupBoxServer.Controls.Add(this.buttonStartServer);
            this.groupBoxServer.Location = new System.Drawing.Point(16, 15);
            this.groupBoxServer.Name = "groupBoxServer";
            this.groupBoxServer.Size = new System.Drawing.Size(340, 74);
            this.groupBoxServer.TabIndex = 0;
            this.groupBoxServer.TabStop = false;
            this.groupBoxServer.Text = "Server (optional — TCP)";
            //
            // labelPorts
            //
            this.labelPorts.AutoSize = true;
            this.labelPorts.Location = new System.Drawing.Point(14, 33);
            this.labelPorts.Name = "labelPorts";
            this.labelPorts.Size = new System.Drawing.Size(37, 13);
            this.labelPorts.TabIndex = 0;
            this.labelPorts.Text = "Ports:";
            //
            // textBoxVCTPort
            //
            this.textBoxVCTPort.Location = new System.Drawing.Point(57, 30);
            this.textBoxVCTPort.Name = "textBoxVCTPort";
            this.textBoxVCTPort.Size = new System.Drawing.Size(140, 20);
            this.textBoxVCTPort.TabIndex = 1;
            this.textBoxVCTPort.Text = "50000,50050";
            //
            // buttonStartServer
            //
            this.buttonStartServer.Location = new System.Drawing.Point(213, 27);
            this.buttonStartServer.Name = "buttonStartServer";
            this.buttonStartServer.Size = new System.Drawing.Size(112, 26);
            this.buttonStartServer.TabIndex = 2;
            this.buttonStartServer.Text = "Start Server (TCP)";
            this.buttonStartServer.UseVisualStyleBackColor = true;
            this.buttonStartServer.Click += new System.EventHandler(this.buttonStartServer_Click);
            //
            // groupBoxSerial
            //
            this.groupBoxSerial.Controls.Add(this.labelCom);
            this.groupBoxSerial.Controls.Add(this.comboBoxVCTSerial);
            this.groupBoxSerial.Controls.Add(this.buttonRefreshPorts);
            this.groupBoxSerial.Controls.Add(this.labelBaud);
            this.groupBoxSerial.Controls.Add(this.comboBoxBaud);
            this.groupBoxSerial.Controls.Add(this.labelHandshake);
            this.groupBoxSerial.Controls.Add(this.comboBoxHandshake);
            this.groupBoxSerial.Controls.Add(this.buttonStart7EDeviceSerial);
            this.groupBoxSerial.Location = new System.Drawing.Point(16, 98);
            this.groupBoxSerial.Name = "groupBoxSerial";
            this.groupBoxSerial.Size = new System.Drawing.Size(340, 150);
            this.groupBoxSerial.TabIndex = 1;
            this.groupBoxSerial.TabStop = false;
            this.groupBoxSerial.Text = "Serial Device";
            //
            // labelCom
            //
            this.labelCom.AutoSize = true;
            this.labelCom.Location = new System.Drawing.Point(14, 28);
            this.labelCom.Name = "labelCom";
            this.labelCom.Size = new System.Drawing.Size(59, 13);
            this.labelCom.TabIndex = 0;
            this.labelCom.Text = "COM Port:";
            //
            // comboBoxVCTSerial
            //
            this.comboBoxVCTSerial.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.comboBoxVCTSerial.FormattingEnabled = true;
            this.comboBoxVCTSerial.Location = new System.Drawing.Point(79, 25);
            this.comboBoxVCTSerial.Name = "comboBoxVCTSerial";
            this.comboBoxVCTSerial.Size = new System.Drawing.Size(210, 21);
            this.comboBoxVCTSerial.TabIndex = 1;
            //
            // buttonRefreshPorts
            //
            this.buttonRefreshPorts.Location = new System.Drawing.Point(295, 24);
            this.buttonRefreshPorts.Name = "buttonRefreshPorts";
            this.buttonRefreshPorts.Size = new System.Drawing.Size(30, 23);
            this.buttonRefreshPorts.TabIndex = 2;
            this.buttonRefreshPorts.Text = "↻";
            this.buttonRefreshPorts.UseVisualStyleBackColor = true;
            this.buttonRefreshPorts.Click += new System.EventHandler(this.buttonRefreshPorts_Click);
            //
            // labelBaud
            //
            this.labelBaud.AutoSize = true;
            this.labelBaud.Location = new System.Drawing.Point(14, 60);
            this.labelBaud.Name = "labelBaud";
            this.labelBaud.Size = new System.Drawing.Size(37, 13);
            this.labelBaud.TabIndex = 3;
            this.labelBaud.Text = "Baud:";
            //
            // comboBoxBaud
            //
            this.comboBoxBaud.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.comboBoxBaud.FormattingEnabled = true;
            this.comboBoxBaud.Items.AddRange(new object[] {
            "9600",
            "19200",
            "38400",
            "57600",
            "115200"});
            this.comboBoxBaud.Location = new System.Drawing.Point(79, 57);
            this.comboBoxBaud.Name = "comboBoxBaud";
            this.comboBoxBaud.Size = new System.Drawing.Size(118, 21);
            this.comboBoxBaud.TabIndex = 4;
            //
            // labelHandshake
            //
            this.labelHandshake.AutoSize = true;
            this.labelHandshake.Location = new System.Drawing.Point(14, 92);
            this.labelHandshake.Name = "labelHandshake";
            this.labelHandshake.Size = new System.Drawing.Size(62, 13);
            this.labelHandshake.TabIndex = 5;
            this.labelHandshake.Text = "Handshake:";
            //
            // comboBoxHandshake
            //
            this.comboBoxHandshake.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.comboBoxHandshake.FormattingEnabled = true;
            this.comboBoxHandshake.Items.AddRange(new object[] {
            "None (DTR/DSR)",
            "XON/XOFF",
            "RTS/CTS"});
            this.comboBoxHandshake.Location = new System.Drawing.Point(79, 89);
            this.comboBoxHandshake.Name = "comboBoxHandshake";
            this.comboBoxHandshake.Size = new System.Drawing.Size(118, 21);
            this.comboBoxHandshake.TabIndex = 6;
            //
            // buttonStart7EDeviceSerial
            //
            this.buttonStart7EDeviceSerial.Location = new System.Drawing.Point(213, 113);
            this.buttonStart7EDeviceSerial.Name = "buttonStart7EDeviceSerial";
            this.buttonStart7EDeviceSerial.Size = new System.Drawing.Size(112, 26);
            this.buttonStart7EDeviceSerial.TabIndex = 7;
            this.buttonStart7EDeviceSerial.Text = "Connect";
            this.buttonStart7EDeviceSerial.UseVisualStyleBackColor = true;
            this.buttonStart7EDeviceSerial.Click += new System.EventHandler(this.buttonStart7EDeviceSerial_Click);
            //
            // buttonShowMonitorVCT
            //
            this.buttonShowMonitorVCT.Enabled = false;
            this.buttonShowMonitorVCT.Location = new System.Drawing.Point(16, 258);
            this.buttonShowMonitorVCT.Name = "buttonShowMonitorVCT";
            this.buttonShowMonitorVCT.Size = new System.Drawing.Size(340, 28);
            this.buttonShowMonitorVCT.TabIndex = 2;
            this.buttonShowMonitorVCT.Text = "Show Monitor";
            this.buttonShowMonitorVCT.UseVisualStyleBackColor = true;
            this.buttonShowMonitorVCT.Click += new System.EventHandler(this.buttonShowMonitorVCT_Click);
            //
            // labelStatus
            //
            this.labelStatus.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle;
            this.labelStatus.Location = new System.Drawing.Point(16, 296);
            this.labelStatus.Name = "labelStatus";
            this.labelStatus.Padding = new System.Windows.Forms.Padding(4, 0, 0, 0);
            this.labelStatus.Size = new System.Drawing.Size(340, 22);
            this.labelStatus.TabIndex = 3;
            this.labelStatus.Text = "Stopped";
            this.labelStatus.TextAlign = System.Drawing.ContentAlignment.MiddleLeft;
            //
            // FormMain
            //
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(372, 330);
            this.Controls.Add(this.groupBoxServer);
            this.Controls.Add(this.groupBoxSerial);
            this.Controls.Add(this.buttonShowMonitorVCT);
            this.Controls.Add(this.labelStatus);
            this.FormBorderStyle = System.Windows.Forms.FormBorderStyle.FixedSingle;
            this.MaximizeBox = false;
            this.Name = "FormMain";
            this.StartPosition = System.Windows.Forms.FormStartPosition.CenterScreen;
            this.Text = "MABA VCT — Com Server";
            this.groupBoxServer.ResumeLayout(false);
            this.groupBoxServer.PerformLayout();
            this.groupBoxSerial.ResumeLayout(false);
            this.groupBoxSerial.PerformLayout();
            this.ResumeLayout(false);

        }

        #endregion

        private System.Windows.Forms.GroupBox groupBoxServer;
        private System.Windows.Forms.Label labelPorts;
        private System.Windows.Forms.TextBox textBoxVCTPort;
        private System.Windows.Forms.Button buttonStartServer;
        private System.Windows.Forms.GroupBox groupBoxSerial;
        private System.Windows.Forms.Label labelCom;
        private System.Windows.Forms.ComboBox comboBoxVCTSerial;
        private System.Windows.Forms.Button buttonRefreshPorts;
        private System.Windows.Forms.Label labelBaud;
        private System.Windows.Forms.ComboBox comboBoxBaud;
        private System.Windows.Forms.Label labelHandshake;
        private System.Windows.Forms.ComboBox comboBoxHandshake;
        private System.Windows.Forms.Button buttonStart7EDeviceSerial;
        private System.Windows.Forms.Button buttonShowMonitorVCT;
        private System.Windows.Forms.Label labelStatus;
    }
}
