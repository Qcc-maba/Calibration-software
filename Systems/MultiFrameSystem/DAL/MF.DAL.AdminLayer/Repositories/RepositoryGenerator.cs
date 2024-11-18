using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories
{
    public class RepositoryGenerator
    {
        #region Repository Generators

        #region Device

        public Func<Device.IDeviceRepository> Generator_IDeviceRepository { get; set; }
        public Func<Device.IDeviceProcessingRepository> Generator_IDeviceProcessingRepository { get; set; }

        #endregion

        #region Account

        public Func<Account.IAccountRepository> Generator_IAccountRepository { get; set; }

        #endregion

        #region Foldering

        public Func<Foldering.IFolderingProcessingRepository> Generator_IFolderingProcessingRepository { get; set; }
        public Func<Foldering.IFolderingRepository> Generator_IFolderingRepository { get; set; }

        #endregion

        #region Weather

        public Func<Weather.IWeatherRepository> Generator_IWeatherRepository { get; set; }

        #endregion

        #endregion

        #region ctor

        public RepositoryGenerator()
        {

        }

        #endregion
    }
}
