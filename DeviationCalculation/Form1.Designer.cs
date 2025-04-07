namespace DeviationCalculation
{
    partial class Form1
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
            this.textBoxTemperature = new System.Windows.Forms.TextBox();
            this.textBoxHum = new System.Windows.Forms.TextBox();
            this.label2 = new System.Windows.Forms.Label();
            this.button1 = new System.Windows.Forms.Button();
            this.label3 = new System.Windows.Forms.Label();
            this.textBoxValue = new System.Windows.Forms.TextBox();
            this.textBoxMaster = new System.Windows.Forms.TextBox();
            this.label4 = new System.Windows.Forms.Label();
            this.SuspendLayout();
            // 
            // label1
            // 
            this.label1.AutoSize = true;
            this.label1.Location = new System.Drawing.Point(32, 38);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(99, 13);
            this.label1.TabIndex = 0;
            this.label1.Text = "Temperature value:";
            // 
            // textBoxTemperature
            // 
            this.textBoxTemperature.Location = new System.Drawing.Point(35, 73);
            this.textBoxTemperature.Name = "textBoxTemperature";
            this.textBoxTemperature.Size = new System.Drawing.Size(100, 20);
            this.textBoxTemperature.TabIndex = 1;
            this.textBoxTemperature.Text = "10";
            // 
            // textBoxHum
            // 
            this.textBoxHum.Location = new System.Drawing.Point(169, 73);
            this.textBoxHum.Name = "textBoxHum";
            this.textBoxHum.Size = new System.Drawing.Size(100, 20);
            this.textBoxHum.TabIndex = 3;
            this.textBoxHum.Text = "10";
            // 
            // label2
            // 
            this.label2.AutoSize = true;
            this.label2.Location = new System.Drawing.Point(166, 38);
            this.label2.Name = "label2";
            this.label2.Size = new System.Drawing.Size(79, 13);
            this.label2.TabIndex = 2;
            this.label2.Text = "Humidity value:";
            // 
            // button1
            // 
            this.button1.Location = new System.Drawing.Point(429, 117);
            this.button1.Name = "button1";
            this.button1.Size = new System.Drawing.Size(75, 23);
            this.button1.TabIndex = 4;
            this.button1.Text = "Start";
            this.button1.UseVisualStyleBackColor = true;
            this.button1.Click += new System.EventHandler(this.button1_Click);
            // 
            // label3
            // 
            this.label3.AutoSize = true;
            this.label3.Location = new System.Drawing.Point(426, 38);
            this.label3.Name = "label3";
            this.label3.Size = new System.Drawing.Size(67, 13);
            this.label3.TabIndex = 5;
            this.label3.Text = "The result is:";
            // 
            // textBoxValue
            // 
            this.textBoxValue.Location = new System.Drawing.Point(429, 73);
            this.textBoxValue.Name = "textBoxValue";
            this.textBoxValue.Size = new System.Drawing.Size(100, 20);
            this.textBoxValue.TabIndex = 6;
            // 
            // textBoxMaster
            // 
            this.textBoxMaster.Location = new System.Drawing.Point(302, 73);
            this.textBoxMaster.Name = "textBoxMaster";
            this.textBoxMaster.Size = new System.Drawing.Size(100, 20);
            this.textBoxMaster.TabIndex = 8;
            this.textBoxMaster.Text = "21-538";
            // 
            // label4
            // 
            this.label4.AutoSize = true;
            this.label4.Location = new System.Drawing.Point(299, 38);
            this.label4.Name = "label4";
            this.label4.Size = new System.Drawing.Size(56, 13);
            this.label4.TabIndex = 7;
            this.label4.Text = "Master ID:";
            // 
            // Form1
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(539, 152);
            this.Controls.Add(this.textBoxMaster);
            this.Controls.Add(this.label4);
            this.Controls.Add(this.textBoxValue);
            this.Controls.Add(this.label3);
            this.Controls.Add(this.button1);
            this.Controls.Add(this.textBoxHum);
            this.Controls.Add(this.label2);
            this.Controls.Add(this.textBoxTemperature);
            this.Controls.Add(this.label1);
            this.Name = "Form1";
            this.Text = "Deviation for humidity";
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        #endregion

        private System.Windows.Forms.Label label1;
        private System.Windows.Forms.TextBox textBoxTemperature;
        private System.Windows.Forms.TextBox textBoxHum;
        private System.Windows.Forms.Label label2;
        private System.Windows.Forms.Button button1;
        private System.Windows.Forms.Label label3;
        private System.Windows.Forms.TextBox textBoxValue;
        private System.Windows.Forms.TextBox textBoxMaster;
        private System.Windows.Forms.Label label4;
    }
}

