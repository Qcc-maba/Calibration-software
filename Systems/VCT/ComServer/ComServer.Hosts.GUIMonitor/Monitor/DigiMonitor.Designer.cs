namespace Maba.VCT.CommServer.Monitor
{
    partial class DigiMonitor
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
            this.label2 = new System.Windows.Forms.Label();
            this.listViewDigiBare = new System.Windows.Forms.ListView();
            this.columnHeader1 = ((System.Windows.Forms.ColumnHeader)(new System.Windows.Forms.ColumnHeader()));
            this.columnHeader2 = ((System.Windows.Forms.ColumnHeader)(new System.Windows.Forms.ColumnHeader()));
            this.SuspendLayout();
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(7, 11);
            this.label2.Margin = new System.Windows.Forms.Padding(2, 0, 2, 0);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(86, 13);
            this.label2.TabIndex = 7;
            this.label2.Text = "Bare Connection";
            // 
            // listViewDigiBare
            // 
            this.listViewDigiBare.Columns.AddRange(new System.Windows.Forms.ColumnHeader[] {
            this.columnHeader1,
            this.columnHeader2});
            this.listViewDigiBare.GridLines = true;
            this.listViewDigiBare.Location = new System.Drawing.Point(9, 46);
            this.listViewDigiBare.Margin = new System.Windows.Forms.Padding(2, 2, 2, 2);
            this.listViewDigiBare.Name = "listViewDigiBare";
            this.listViewDigiBare.Size = new System.Drawing.Size(285, 246);
            this.listViewDigiBare.TabIndex = 6;
            this.listViewDigiBare.UseCompatibleStateImageBehavior = false;
            this.listViewDigiBare.View = System.Windows.Forms.View.Details;
            this.listViewDigiBare.SelectedIndexChanged += new System.EventHandler(this.listViewDigiBare_SelectedIndexChanged);
            // 
            // columnHeader1
            // 
            this.columnHeader1.Text = "Com Layer";
            this.columnHeader1.Width = 188;
            // 
            // columnHeader2
            // 
            this.columnHeader2.Text = "Connected";
            this.columnHeader2.Width = 196;
            // 
            // DigiMonitor
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(305, 332);
            this.Controls.Add(this.label2);
            this.Controls.Add(this.listViewDigiBare);
            this.Margin = new System.Windows.Forms.Padding(2, 2, 2, 2);
            this.Name = "DigiMonitor";
            this.Text = "DigiMonitor";
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        #endregion
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.ListView listViewDigiBare;
        private System.Windows.Forms.ColumnHeader columnHeader1;
        private System.Windows.Forms.ColumnHeader columnHeader2;
    }
}