namespace Maba.VCT.CommServer.Monitor
{
    partial class VCTMonitor
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
            this.components = new System.ComponentModel.Container();
            this.listViewVCTIdentified = new System.Windows.Forms.ListView();
            this.columnHeaderComLayer = ((System.Windows.Forms.ColumnHeader)(new System.Windows.Forms.ColumnHeader()));
            this.columnHeaderConnected = ((System.Windows.Forms.ColumnHeader)(new System.Windows.Forms.ColumnHeader()));
            this.columnHeaderSN = ((System.Windows.Forms.ColumnHeader)(new System.Windows.Forms.ColumnHeader()));
            this.columnHeaderBL_Name = ((System.Windows.Forms.ColumnHeader)(new System.Windows.Forms.ColumnHeader()));
            this.listViewVCTBare = new System.Windows.Forms.ListView();
            this.columnHeader1 = ((System.Windows.Forms.ColumnHeader)(new System.Windows.Forms.ColumnHeader()));
            this.columnHeader2 = ((System.Windows.Forms.ColumnHeader)(new System.Windows.Forms.ColumnHeader()));
            this.groupBox1 = new System.Windows.Forms.GroupBox();
            this.groupBox2 = new System.Windows.Forms.GroupBox();
            this.splitContainer1 = new System.Windows.Forms.SplitContainer();
            this.timer_lists = new System.Windows.Forms.Timer(this.components);
            this.label1 = new System.Windows.Forms.Label();
            this.textBox_totalBares = new System.Windows.Forms.TextBox();
            this.label2 = new System.Windows.Forms.Label();
            this.textBox_totalIdentified = new System.Windows.Forms.TextBox();
            this.panel1 = new System.Windows.Forms.Panel();
            this.linkLabel_clearBares = new System.Windows.Forms.LinkLabel();
            this.panel2 = new System.Windows.Forms.Panel();
            this.groupBox1.SuspendLayout();
            this.groupBox2.SuspendLayout();
            ((System.ComponentModel.ISupportInitialize)(this.splitContainer1)).BeginInit();
            this.splitContainer1.Panel1.SuspendLayout();
            this.splitContainer1.Panel2.SuspendLayout();
            this.splitContainer1.SuspendLayout();
            this.panel1.SuspendLayout();
            this.panel2.SuspendLayout();
            this.SuspendLayout();
            // 
            // listViewVCTIdentified
            // 
            this.listViewVCTIdentified.Columns.AddRange(new System.Windows.Forms.ColumnHeader[] {
            this.columnHeaderComLayer,
            this.columnHeaderConnected,
            this.columnHeaderSN,
            this.columnHeaderBL_Name});
            this.listViewVCTIdentified.Dock = System.Windows.Forms.DockStyle.Fill;
            this.listViewVCTIdentified.FullRowSelect = true;
            this.listViewVCTIdentified.GridLines = true;
            this.listViewVCTIdentified.HideSelection = false;
            this.listViewVCTIdentified.Location = new System.Drawing.Point(4, 19);
            this.listViewVCTIdentified.Margin = new System.Windows.Forms.Padding(3, 2, 3, 2);
            this.listViewVCTIdentified.Name = "listViewVCTIdentified";
            this.listViewVCTIdentified.Size = new System.Drawing.Size(774, 409);
            this.listViewVCTIdentified.Sorting = System.Windows.Forms.SortOrder.Ascending;
            this.listViewVCTIdentified.TabIndex = 0;
            this.listViewVCTIdentified.UseCompatibleStateImageBehavior = false;
            this.listViewVCTIdentified.View = System.Windows.Forms.View.Details;
            this.listViewVCTIdentified.DoubleClick += new System.EventHandler(this.listViewVCTIdentified_DoubleClick);
            // 
            // columnHeaderComLayer
            // 
            this.columnHeaderComLayer.Text = "Com Layer";
            this.columnHeaderComLayer.Width = 92;
            // 
            // columnHeaderConnected
            // 
            this.columnHeaderConnected.Text = "Connected";
            this.columnHeaderConnected.Width = 93;
            // 
            // columnHeaderSN
            // 
            this.columnHeaderSN.Text = "SN";
            this.columnHeaderSN.Width = 142;
            // 
            // columnHeaderBL_Name
            // 
            this.columnHeaderBL_Name.Text = "BL Name";
            this.columnHeaderBL_Name.Width = 211;
            // 
            // listViewVCTBare
            // 
            this.listViewVCTBare.Columns.AddRange(new System.Windows.Forms.ColumnHeader[] {
            this.columnHeader1,
            this.columnHeader2});
            this.listViewVCTBare.Dock = System.Windows.Forms.DockStyle.Fill;
            this.listViewVCTBare.FullRowSelect = true;
            this.listViewVCTBare.GridLines = true;
            this.listViewVCTBare.HideSelection = false;
            this.listViewVCTBare.Location = new System.Drawing.Point(4, 19);
            this.listViewVCTBare.Margin = new System.Windows.Forms.Padding(3, 2, 3, 2);
            this.listViewVCTBare.Name = "listViewVCTBare";
            this.listViewVCTBare.Size = new System.Drawing.Size(384, 409);
            this.listViewVCTBare.Sorting = System.Windows.Forms.SortOrder.Ascending;
            this.listViewVCTBare.TabIndex = 2;
            this.listViewVCTBare.UseCompatibleStateImageBehavior = false;
            this.listViewVCTBare.View = System.Windows.Forms.View.Details;
            // 
            // columnHeader1
            // 
            this.columnHeader1.Text = "Com Layer";
            this.columnHeader1.Width = 115;
            // 
            // columnHeader2
            // 
            this.columnHeader2.Text = "Connected";
            this.columnHeader2.Width = 139;
            // 
            // groupBox1
            // 
            this.groupBox1.Controls.Add(this.listViewVCTBare);
            this.groupBox1.Dock = System.Windows.Forms.DockStyle.Fill;
            this.groupBox1.Location = new System.Drawing.Point(0, 41);
            this.groupBox1.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.groupBox1.Name = "groupBox1";
            this.groupBox1.Padding = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.groupBox1.Size = new System.Drawing.Size(392, 432);
            this.groupBox1.TabIndex = 4;
            this.groupBox1.TabStop = false;
            this.groupBox1.Text = "Bare Connections";
            // 
            // groupBox2
            // 
            this.groupBox2.Controls.Add(this.listViewVCTIdentified);
            this.groupBox2.Dock = System.Windows.Forms.DockStyle.Fill;
            this.groupBox2.Location = new System.Drawing.Point(0, 41);
            this.groupBox2.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.groupBox2.Name = "groupBox2";
            this.groupBox2.Padding = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.groupBox2.Size = new System.Drawing.Size(782, 432);
            this.groupBox2.TabIndex = 5;
            this.groupBox2.TabStop = false;
            this.groupBox2.Text = "Identified Devices";
            // 
            // splitContainer1
            // 
            this.splitContainer1.Dock = System.Windows.Forms.DockStyle.Fill;
            this.splitContainer1.Location = new System.Drawing.Point(0, 0);
            this.splitContainer1.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.splitContainer1.Name = "splitContainer1";
            // 
            // splitContainer1.Panel1
            // 
            this.splitContainer1.Panel1.Controls.Add(this.groupBox1);
            this.splitContainer1.Panel1.Controls.Add(this.panel1);
            // 
            // splitContainer1.Panel2
            // 
            this.splitContainer1.Panel2.Controls.Add(this.groupBox2);
            this.splitContainer1.Panel2.Controls.Add(this.panel2);
            this.splitContainer1.Size = new System.Drawing.Size(1179, 473);
            this.splitContainer1.SplitterDistance = 392;
            this.splitContainer1.SplitterWidth = 5;
            this.splitContainer1.TabIndex = 6;
            // 
            // timer_lists
            // 
            this.timer_lists.Enabled = true;
            this.timer_lists.Interval = 2000;
            this.timer_lists.Tick += new System.EventHandler(this.timer_lists_Tick);
            // 
            // label1
            // 
            this.label1.AutoSize = true;
            this.label1.Location = new System.Drawing.Point(14, 13);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(39, 16);
            this.label1.TabIndex = 0;
            this.label1.Text = "Total";
            // 
            // textBox_totalBares
            // 
            this.textBox_totalBares.Location = new System.Drawing.Point(65, 10);
            this.textBox_totalBares.Name = "textBox_totalBares";
            this.textBox_totalBares.ReadOnly = true;
            this.textBox_totalBares.Size = new System.Drawing.Size(100, 22);
            this.textBox_totalBares.TabIndex = 1;
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(25, 13);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(39, 16);
            this.label2.TabIndex = 2;
            this.label2.Text = "Total";
            // 
            // textBox_totalIdentified
            // 
            this.textBox_totalIdentified.Location = new System.Drawing.Point(70, 10);
            this.textBox_totalIdentified.Name = "textBox_totalIdentified";
            this.textBox_totalIdentified.ReadOnly = true;
            this.textBox_totalIdentified.Size = new System.Drawing.Size(100, 22);
            this.textBox_totalIdentified.TabIndex = 3;
            // 
            // panel1
            // 
            this.panel1.Controls.Add(this.linkLabel_clearBares);
            this.panel1.Controls.Add(this.label1);
            this.panel1.Controls.Add(this.textBox_totalBares);
            this.panel1.Dock = System.Windows.Forms.DockStyle.Top;
            this.panel1.Location = new System.Drawing.Point(0, 0);
            this.panel1.Name = "panel1";
            this.panel1.Size = new System.Drawing.Size(392, 41);
            this.panel1.TabIndex = 5;
            // 
            // linkLabel_clearBares
            // 
            this.linkLabel_clearBares.AutoSize = true;
            this.linkLabel_clearBares.Location = new System.Drawing.Point(337, 16);
            this.linkLabel_clearBares.Name = "linkLabel_clearBares";
            this.linkLabel_clearBares.Size = new System.Drawing.Size(40, 16);
            this.linkLabel_clearBares.TabIndex = 2;
            this.linkLabel_clearBares.TabStop = true;
            this.linkLabel_clearBares.Text = "Clear";
            this.linkLabel_clearBares.LinkClicked += new System.Windows.Forms.LinkLabelLinkClickedEventHandler(this.linkLabel_clearBares_LinkClicked);
            // 
            // panel2
            // 
            this.panel2.Controls.Add(this.textBox_totalIdentified);
            this.panel2.Controls.Add(this.label2);
            this.panel2.Dock = System.Windows.Forms.DockStyle.Top;
            this.panel2.Location = new System.Drawing.Point(0, 0);
            this.panel2.Name = "panel2";
            this.panel2.Size = new System.Drawing.Size(782, 41);
            this.panel2.TabIndex = 6;
            // 
            // VCTMonitor
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(8F, 16F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(1179, 473);
            this.Controls.Add(this.splitContainer1);
            this.Margin = new System.Windows.Forms.Padding(3, 2, 3, 2);
            this.Name = "VCTMonitor";
            this.Text = "VCTMonitor";
            this.groupBox1.ResumeLayout(false);
            this.groupBox2.ResumeLayout(false);
            this.splitContainer1.Panel1.ResumeLayout(false);
            this.splitContainer1.Panel2.ResumeLayout(false);
            ((System.ComponentModel.ISupportInitialize)(this.splitContainer1)).EndInit();
            this.splitContainer1.ResumeLayout(false);
            this.panel1.ResumeLayout(false);
            this.panel1.PerformLayout();
            this.panel2.ResumeLayout(false);
            this.panel2.PerformLayout();
            this.ResumeLayout(false);

        }

        #endregion

        private System.Windows.Forms.ListView listViewVCTIdentified;
        private System.Windows.Forms.ColumnHeader columnHeaderComLayer;
        private System.Windows.Forms.ColumnHeader columnHeaderConnected;
        private System.Windows.Forms.ColumnHeader columnHeaderSN;
        private System.Windows.Forms.ColumnHeader columnHeaderBL_Name;
        private System.Windows.Forms.ListView listViewVCTBare;
        private System.Windows.Forms.ColumnHeader columnHeader1;
        private System.Windows.Forms.ColumnHeader columnHeader2;
        private System.Windows.Forms.GroupBox groupBox1;
        private System.Windows.Forms.GroupBox groupBox2;
        private System.Windows.Forms.SplitContainer splitContainer1;
        private System.Windows.Forms.Timer timer_lists;
        private System.Windows.Forms.TextBox textBox_totalIdentified;
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.TextBox textBox_totalBares;
        private System.Windows.Forms.Label label1;
        private System.Windows.Forms.Panel panel1;
        private System.Windows.Forms.LinkLabel linkLabel_clearBares;
        private System.Windows.Forms.Panel panel2;
    }
}