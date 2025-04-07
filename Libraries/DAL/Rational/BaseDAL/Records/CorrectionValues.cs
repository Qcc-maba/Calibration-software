using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Mail;
using System.Text;
using System.Threading.Tasks;

namespace Maba.DAL.BaseDAL.Records
{
    public class CorrectionValues
    {

        #region Members
        public double TemperatureValue { get; set; }
        public double Deviation { get; set; }
        public double HumidityValue { get; set; }
        #endregion

        public CorrectionValues()
        {

        }
        public CorrectionValues(double temprature,  double deviation)
        {
            this.TemperatureValue = temprature;
            this.Deviation = deviation;
        }

        public CorrectionValues(List<double> temp)
        {
            this.TemperatureValue = temp[0];
            this.HumidityValue = temp[1];
            this.Deviation = temp[2];
        }
    }
}
