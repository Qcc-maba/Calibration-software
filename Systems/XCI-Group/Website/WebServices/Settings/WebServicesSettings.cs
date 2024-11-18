using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Web;
using System.Xml.Serialization;
using OWINLibrary = Maba.Connectors.OWINLibrary;
using JsonHelpersLibrary = Maba.Connectors.JsonHelpersLibrary;
using CommonWebAPI = Maba.Hydra2.Systems.Common.CommonWebAPI;
using Maba.Connectors.ElasticsearchLibrary;

namespace Maba.Hydra2.Systems.XCIGroup.WebServices.Settings
{
    public class WebServicesSettings : Hydra2.Systems.Common.CommonWebAPI.DependencyResolves.BaseSettingsCarrier
    {
        #region properties

        public BL.ViewModelLayer.Settings.ViewModelLayerSettings ViewModelLayerSettings { get; set; }
        public GeneralProperties Properties { get; set; }


        #endregion

        #region ctor

        public WebServicesSettings()
            : base()
        {
        }

        #endregion

    }
}