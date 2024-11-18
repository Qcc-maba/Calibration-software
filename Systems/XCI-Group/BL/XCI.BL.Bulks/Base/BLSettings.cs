using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.Bulks.Base
{
    public class BLSettings
    {
        //public const string SETTING_LOCATOR_NAME = "MF#DAL#ViewModelLayerSettings";
        public DAL.BulksLayer.Repositories.RepositoryGenerator DAL_BulksLayer_RepositoriesGenerator { get; set; }
        public DAL.DataAccessLayer.Repositories.RepositoryGenerator DAL_DataAccessLayer_RepositoriesGenerator { get; set; }

        public Connectors.QueueLibrary.QueueGenerator DAL_QueueGenerator_Generator { get; set; }

    }
}
