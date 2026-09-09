using ComServerBL.Hydra2.DAL.Calibration;
using Maba.VCT.CommServer.BL.HydraDevices.Device.Calculations;
using System;
using System.Windows.Forms;

namespace DeviationCalculation
{
    public partial class Form1 : Form
    {
        public Form1()
        {
            InitializeComponent();
        }

        private async void button1_Click(object sender, EventArgs e)
        {
            var repository = new CalibrationRepository();
            var HC = new HydraCalculations(repository);
            double temperautre = double.Parse(textBoxTemperature.Text);
            double humidity = double.Parse(textBoxHum.Text);

            var loaded = await repository.LoadCorrectionValues("GetSensorByName", "@MabaID", textBoxMaster.Text);
            textBoxValue.Text = repository.CalcDeviationForTemperatureAndHumidity(temperautre, humidity, textBoxMaster.Text).Item1.ToString();
        }
    }
}
