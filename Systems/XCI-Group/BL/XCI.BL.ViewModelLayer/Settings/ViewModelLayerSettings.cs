using Maba.Connectors.ElasticsearchLibrary;
using Maba.Connectors.WeatherServices.PETProcessing.AgricultureData;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Settings
{
    public class ViewModelLayerSettings
    {
        #region properties

        //Repositories Generators
        [Newtonsoft.Json.JsonIgnore]
        [System.Xml.Serialization.XmlIgnore]
        public Func<DAL.DataAccessLayer.Repositories.Admin.IAdminRepository> AdminRepositoryFunc { get; set; }

        [Newtonsoft.Json.JsonIgnore]
        [System.Xml.Serialization.XmlIgnore]
        public Func<IAgricultureData> AgricultureRepositoryFunc { get; set; }

        public ElasticSettings PETRepositorySettings_ES { get; set; }

        public StorageSettings ZonesFileSettings { get; set; }


        #endregion

        #region ctor

        public ViewModelLayerSettings()
        {

        }

        #endregion
    }
}
