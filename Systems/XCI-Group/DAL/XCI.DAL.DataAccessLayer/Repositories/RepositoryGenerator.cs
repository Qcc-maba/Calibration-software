using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Repositories
{
    public class RepositoryGenerator
    {
        #region Repository Generators

        #region Admin

        public Func<Admin.IAdminRepository> IAdminRepository { get; set; }

        #endregion

        #region Admin

        public Func<Device.IDeviceProcessingRepository> IDeviceProcessingRepository { get; set; }

        #endregion

        #endregion

        #region ctor

        public RepositoryGenerator()
        {

        }

        #endregion
    }
}
