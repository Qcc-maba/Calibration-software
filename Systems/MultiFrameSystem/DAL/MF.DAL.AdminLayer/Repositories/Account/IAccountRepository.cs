using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories.Account
{
    public interface IAccountRepository : IDisposable
    {
        #region Account

        bool UpdateMessagesCount(string UserEmail, int Count2Add);
        bool ResetMessagesCount(long UserID);
        AdminLayer.Models.Exchange GetExchange(long UserID);
        AdminLayer.Models.Exchange GetExchange_ByGUID(string UserGUID);
        AdminLayer.Models.Exchange GetExchange_ByEmail(string UserEmail);


        long AddUser(AdminLayer.Models.AccountUser NewUser);
        AdminLayer.Models.AccountUser GetUser(long UserID);
        AdminLayer.Models.AccountUser GetUser(string UserEmail);
        bool DeleteUser(long UserID);
        bool UpdateUser(AdminLayer.Models.AccountUser UpdatedUser);

        int CountUserMessages(string UserEmail);
        Models.GlobalizationZone[] GetGlobalizationZones(int? FilterOffset);
        bool RefreshUserExhange(long newOwnerUserID);

        #endregion
    }
}
