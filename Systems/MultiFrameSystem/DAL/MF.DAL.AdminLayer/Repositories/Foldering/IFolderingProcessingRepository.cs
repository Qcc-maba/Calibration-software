using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories.Foldering
{
    public interface IFolderingProcessingRepository : IDisposable
    {
        long GetNextSiteGroup(long CurrentGroupID);
        IEnumerable<Models.MainSite> GetAllSiteInGroup(long FirstGroupID, int PageNumber, int PageSize);
    }
}
