using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Base
{
    public class ViewModelSettings
    {
        #region Generators (excluded from serializations)

        [Newtonsoft.Json.JsonIgnore]
        [System.Xml.Serialization.XmlIgnore]
        public DAL.AdminLayer.Repositories.RepositoryGenerator DAL_AdminLayer_RepositoriesGenerator { get; set; }

        [Newtonsoft.Json.JsonIgnore]
        [System.Xml.Serialization.XmlIgnore]
        public DAL.BulksLayer.Repositories.RepositoryGenerator DAL_BulksLayer_RepositoriesGenerator { get; set; }

        #endregion

        #region settings

        public Connectors.WeatherServices.Settings.ForecastWeatherSettings Weather_Settings { set; get; }
        public DAL.BulksLayer.Repositories.Weather.ES.WeatherESSettings WeatherRepositorySettings_ES { get; set; }

        public KnownDeviceType[] KnownDeviceTypes { get; set; }

        #endregion 

        #region  public methods

        public void BuildDefaultKnownDeviceTypes()
        {
            this.KnownDeviceTypes = new Base.KnownDeviceType[]
            {
                new Base.KnownDeviceType()
                {
                    DeviceTypeName ="Hydra2",
                    SN_Pattern = @"^(\d{16}|Hydra20(\d|[a-z]|A-Z]){4}\d{8})$",
                    //starts with Hydra20, 4 random chars (digit or char) and the 8 digits
                    //or 16 digits
                    SN_Examples= new string[] { "0000000000000001", "Hydra20abcd00000001" },
                    Remote_API_URL="http://localhost:63095"
                },
                new Base.KnownDeviceType() {
                    DeviceTypeName ="XCI",
                    //starts with XCIW, 4 random chars (digit or char) and the 8 digits
                    SN_Pattern =@"^XCIW(\d|[a-z]|A-Z]){4}\d{8}$",
                    SN_Examples=new string[] { "XCIWbdca00000001", "XCIWb3ca00000001" },
                    Remote_API_URL="http://localhost:63095"
                },
                new Base.KnownDeviceType() {
                    DeviceTypeName ="XCI-WIFI",
                    //starts with XCIR, 4 random chars (digit or char) and the 8 digits
                    SN_Pattern = @"^XCIR(\d|[a-z]|A-Z]){4}\d{8}$",
                    SN_Examples=new string[] { "XCIRbdfa00000001", "XCIRb4fa00000001" },
                    Remote_API_URL="http://localhost:63095"
                },
            };
        }

        public KnownDeviceType SearchKnownDeviceType(string SN)
        {
            if (this.KnownDeviceTypes == null)
                return null;

            //search for known type
            Base.KnownDeviceType _knownType = null;
            for (int i = 0; i < this.KnownDeviceTypes.Length; i++)
            {
                if (this.KnownDeviceTypes[i].IsMatch(SN))
                {
                    _knownType = this.KnownDeviceTypes[i];
                    break;
                }
            }

            return _knownType;
        }

        public Connectors.WeatherServices.IWeatherProvider Get_WeatherConnector()
        {
            if (Weather_Settings == null)
                return null;

            return Weather_Settings.GetPrefferedProvider();
        }

        #endregion
    }
}
