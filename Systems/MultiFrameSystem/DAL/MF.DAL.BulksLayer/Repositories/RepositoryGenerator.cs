using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.BulksLayer.Repositories
{
    public class RepositoryGenerator
    {
        #region Repository Generators

        public Func<InboxMessages.IInboxMessagesRepository> Generator_IInboxMessagesRepository { get; set; }
        public Func<Weather.IWeatherForecastsRepository> Generator_IWeatherForecastsRepository { get; set; }

        #endregion

        #region ctor

        public RepositoryGenerator()
        {

        }

        #endregion

    }
}
