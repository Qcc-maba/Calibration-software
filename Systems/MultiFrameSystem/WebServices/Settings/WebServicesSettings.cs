using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Web;
using System.Xml.Serialization;
using OWINLibrary = Maba.Connectors.OWINLibrary;

using JsonHelpersLibrary = Maba.Connectors.JsonHelpersLibrary;
using Maba.Connectors.AWS.SQS;
using Maba.Connectors.EmailServices;
using Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Base;

namespace Maba.Hydra2.Systems.MF.WebServices.Settings
{
    public class WebServicesSettings : Hydra2.Systems.Common.CommonWebAPI.DependencyResolves.BaseSettingsCarrier
    {
        #region properties
        public GeneralProperties Properties { get; set; }

        public ViewModelSettings ViewModelLayerSettings { get; set; }



        /*public CachedMemorySettings CachedMemory_Settings { set; get; }
        public SQSSettings SQS_Settings { set; get; }
        public ProcessSetting Irrigation_Setting { set; get; }
        public ProcessSetting Alert_Setting { set; get; }
        public ProcessSetting Connection_Setting { set; get; }
        public EmailServiceSettings Email_Settings { set; get; }
        public MessagesDALSetting Messages_DALSetting { set; get; }*/
        #endregion

        #region ctor

        public WebServicesSettings()
            : base()
        {
            Properties = new GeneralProperties();
           // ViewModelLayerSettings = new ViewModelLayer.Settings.ViewModelLayerSettings();

            /*CachedMemory_Settings = new CachedMemorySettings();
            SQS_Settings = new SQSSettings();
            DAL_Settings = new DALSettings();
            Irrigation_Setting = new ProcessSetting();
            Alert_Setting = new ProcessSetting();
            Connection_Setting = new ProcessSetting();
            Email_Settings = new EmailServiceSettings();
            Weather_Settings = new WeatherSettings();
            Elastic_Settings = new ElasticSettings();
            Messages_DALSetting = new MessagesDALSetting();*/
        }

        #endregion
    }
}