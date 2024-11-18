namespace Maba.VCT.CommServer.Monitor
{
    partial class APIProtocolForm
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
            this.comboBoxDigiPackets = new System.Windows.Forms.ComboBox();
            this.listViewDigiAPI = new System.Windows.Forms.ListView();
            this.columnHeader1 = ((System.Windows.Forms.ColumnHeader)(new System.Windows.Forms.ColumnHeader()));
            this.columnHeader2 = ((System.Windows.Forms.ColumnHeader)(new System.Windows.Forms.ColumnHeader()));
            this.columnHeader3 = ((System.Windows.Forms.ColumnHeader)(new System.Windows.Forms.ColumnHeader()));
            this.listViewDigiNodes = new System.Windows.Forms.ListView();
            this.columnHeader4 = ((System.Windows.Forms.ColumnHeader)(new System.Windows.Forms.ColumnHeader()));
            this.columnHeader5 = ((System.Windows.Forms.ColumnHeader)(new System.Windows.Forms.ColumnHeader()));
            this.label2 = new System.Windows.Forms.Label();
            this.buttonSendDigiAPIPAcket = new System.Windows.Forms.Button();
            this.propertyGridSingleNode = new System.Windows.Forms.PropertyGrid();
            this.SuspendLayout();
            // 
            // label1
            // 
            this.label1.AutoSize = true;
            this.label1.Location = new System.Drawing.Point(41, 32);
            this.label1.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(121, 17);
            this.label1.TabIndex = 0;
            this.label1.Text = "API Common.Packet Send: ";
            // 
            // comboBoxDigiPackets
            // 
            this.comboBoxDigiPackets.FormattingEnabled = true;
            this.comboBoxDigiPackets.Items.AddRange(new object[] {
            "ND",
            "DB"});
            this.comboBoxDigiPackets.Location = new System.Drawing.Point(200, 22);
            this.comboBoxDigiPackets.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.comboBoxDigiPackets.Name = "comboBoxDigiPackets";
            this.comboBoxDigiPackets.Size = new System.Drawing.Size(160, 24);
            this.comboBoxDigiPackets.TabIndex = 1;
            this.comboBoxDigiPackets.Text = "ND";
            // 
            // listViewDigiAPI
            // 
            this.listViewDigiAPI.Columns.AddRange(new System.Windows.Forms.ColumnHeader[] {
            this.columnHeader1,
            this.columnHeader2,
            this.columnHeader3});
            this.listViewDigiAPI.GridLines = true;
            this.listViewDigiAPI.Location = new System.Drawing.Point(45, 91);
            this.listViewDigiAPI.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.listViewDigiAPI.Name = "listViewDigiAPI";
            this.listViewDigiAPI.Size = new System.Drawing.Size(624, 318);
            this.listViewDigiAPI.TabIndex = 2;
            this.listViewDigiAPI.UseCompatibleStateImageBehavior = false;
            this.listViewDigiAPI.View = System.Windows.Forms.View.Details;
            // 
            // columnHeader1
            // 
            this.columnHeader1.Text = "Date";
            // 
            // columnHeader2
            // 
            this.columnHeader2.Text = "Packet";
            this.columnHeader2.Width = 72;
            // 
            // columnHeader3
            // 
            this.columnHeader3.Text = "Data";
            this.columnHeader3.Width = 254;
            // 
            // listViewDigiNodes
            // 
            this.listViewDigiNodes.Columns.AddRange(new System.Windows.Forms.ColumnHeader[] {
            this.columnHeader4,
            this.columnHeader5});
            this.listViewDigiNodes.GridLines = true;
            this.listViewDigiNodes.Location = new System.Drawing.Point(752, 91);
            this.listViewDigiNodes.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.listViewDigiNodes.Name = "listViewDigiNodes";
            this.listViewDigiNodes.Size = new System.Drawing.Size(285, 318);
            this.listViewDigiNodes.TabIndex = 3;
            this.listViewDigiNodes.UseCompatibleStateImageBehavior = false;
            this.listViewDigiNodes.View = System.Windows.Forms.View.Details;
            this.listViewDigiNodes.SelectedIndexChanged += new System.EventHandler(this.listView1_SelectedIndexChanged);
            // 
            // columnHeader4
            // 
            this.columnHeader4.Text = "MAC";
            this.columnHeader4.Width = 119;
            // 
            // columnHeader5
            // 
            this.columnHeader5.Text = "Connected";
            this.columnHeader5.Width = 92;
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(748, 32);
            this.label2.Margin = new System.Windows.Forms.Padding(4, 0, 4, 0);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(49, 17);
            this.label2.TabIndex = 4;
            this.label2.Text = "Nodes";
            // 
            // buttonSendDigiAPIPAcket
            // 
            this.buttonSendDigiAPIPAcket.Location = new System.Drawing.Point(411, 18);
            this.buttonSendDigiAPIPAcket.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.buttonSendDigiAPIPAcket.Name = "buttonSendDigiAPIPAcket";
            this.buttonSendDigiAPIPAcket.Size = new System.Drawing.Size(100, 28);
            this.buttonSendDigiAPIPAcket.TabIndex = 5;
            this.buttonSendDigiAPIPAcket.Text = "Send";
            this.buttonSendDigiAPIPAcket.UseVisualStyleBackColor = true;
            this.buttonSendDigiAPIPAcket.Click += new System.EventHandler(this.buttonSendDigiAPIPAcket_Click);
            // 
            // propertyGridSingleNode
            // 
            this.propertyGridSingleNode.Location = new System.Drawing.Point(1089, 91);
            this.propertyGridSingleNode.Margin = new System.Windows.Forms.Padding(4, 4, 4, 4);
            this.propertyGridSingleNode.Name = "propertyGridSingleNode";
            this.propertyGridSingleNode.Size = new System.Drawing.Size(253, 319);
            this.propertyGridSingleNode.TabIndex = 6;
            // 
            // APIProtocolForm
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(8F, 16F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(1359, 450);
            this.Controls.Add(this.propertyGridSingleNode);
            this.Controls.Add(this.buttonSendDigiAPIPAcket);
            this.Controls.Add(this.label2);
            this.Controls.Add(this.listViewDigiNodes);
            this.Controls.Add(this.listViewDigiAPI);
            this.Controls.Add(this.comboBoxDigiPackets);
            this.Controls.Add(this.label1);
            this.Margin = new System.Windows.Forms.Padding(3, 2, 3, 2);
            this.Name = "APIProtocolForm";
            this.Text = "APIProtocol";
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        #endregion

        private System.Windows.Forms.Label label1;
        private System.Windows.Forms.ComboBox comboBoxDigiPackets;
        private System.Windows.Forms.ListView listViewDigiAPI;
        private System.Windows.Forms.ColumnHeader columnHeader1;
        private System.Windows.Forms.ColumnHeader columnHeader2;
        private System.Windows.Forms.ColumnHeader columnHeader3;
        private System.Windows.Forms.ListView listViewDigiNodes;
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.ColumnHeader columnHeader4;
        private System.Windows.Forms.ColumnHeader columnHeader5;
        private System.Windows.Forms.Button buttonSendDigiAPIPAcket;
        private System.Windows.Forms.PropertyGrid propertyGridSingleNode;
    }
}