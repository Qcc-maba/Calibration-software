using Maba.DAL.BaseDAL;
using Maba.VCT.Common.API.RemoteProtocolService;
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
            var connector = new MSSqlServer("KyulanSyncDB");
            connector.Open();
            var HC = new HydraCalculations(connector);
            double temperautre = double.Parse(textBoxTemperature.Text);
            double humidity = double.Parse(textBoxHum.Text);

            var res = HC.RunProcedure("GetSensorByName", textBoxMaster.Text);
            res.Wait();
            textBoxValue.Text= HC.CalcCalibrationDeviationForTemperatureAndHumidity(new LogsResponse(temperautre, humidity), textBoxMaster.Text).Item1.ToString();
        }
    }
}
