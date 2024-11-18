using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.BulksLayer.Repositories
{
    public class RepositoryGenerator
    {
        #region Repository Generators

        public Func<Alerts.IAlertsRepository> Generator_IAlertsRepository { get; set; }

        #endregion

        #region ctor

        public RepositoryGenerator()
        {

        }

        #endregion
    }
}
