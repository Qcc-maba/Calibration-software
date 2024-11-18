using Maba.DAL.BaseDAL;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories.Account.TSQL
{
    public class TSQLAccountRepository : BaseConnector, IAccountRepository
    {
        #region CONSTANTS

        public const string DEFAULT_STRING_CONNECTION = "MFSystemAdminDB";

        #endregion

        #region properties

        #endregion

        #region ctor(s)

        private void initCtor()
        {
        }

        public TSQLAccountRepository()
            : base(DEFAULT_STRING_CONNECTION)
        {
            initCtor();
        }

        public TSQLAccountRepository(string providerName, string stringConnection)
            : base(providerName, stringConnection)
        {
            initCtor();
        }

        public TSQLAccountRepository(string stringConnectionSectionName)
            : base(stringConnectionSectionName)
        {
            initCtor();
        }

        #endregion


        #region Implementation of IAccountRepository

        public bool UpdateMessagesCount(string UserEmail, int Count2Add)
        {
            int rowsAffected = 0;
            bool result = false;
            Connector.GetProcedureResultInt64("Account.UpdateMessagesTotal", new IDataParameter[] {
                                                                        Connector.CreateParameter("UserEmail",UserEmail),
                                                                        Connector.CreateParameter("Count",Count2Add)
                                                                    },
                                                                    out rowsAffected,
                                                                    out result);
            return result;
        }


        public bool ResetMessagesCount(long UserID)
        {
            int rowsAffected = 0;
            bool result = false;
            Connector.GetProcedureResultInt64("Account.ResetMessagesCount", new IDataParameter[] {
                                                                        Connector.CreateParameter("UserID",UserID)
                                                                    },
                                                                    out rowsAffected,
                                                                    out result);
            return result;
        }

        public int CountUserMessages(string UserEmail)
        {
            int rowsAffected = 0;
            bool result = false;
            return Connector.GetProcedureResultInt32("Account.GetCountMessages",
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("UserEmail",UserEmail)},
                                                                    out rowsAffected,
                                                                    out result);
        }


        public bool RefreshUserExhange(long UserID)
        {
            int rowsAffected = 0;
            bool result = false;
            Connector.GetProcedureResultInt32("Account.UpdateStatistics",
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("UserID",UserID)},
                                                                    out rowsAffected,
                                                                    out result);

            return result;
        }

        public AdminLayer.Models.AccountUser GetUser(string UserEmail)
        {
            var user = Connector.GetEntity<AdminLayer.Models.AccountUser>(this.Connector.CreateProcedureEnumerator("Account.GetUser_ByEmail",
                                                           new IDataParameter[] {
                                                                        Connector.CreateParameter("UserEmail",UserEmail)}));
            return user;
        }
        public AdminLayer.Models.Exchange GetExchange(long UserID)
        {
            return Connector.GetEntity<AdminLayer.Models.Exchange>(this.Connector.CreateProcedureEnumerator("Account.GetExchange",
                                                               new IDataParameter[] {
                                                                        Connector.CreateParameter("UserID",UserID)}));
        }

        public AdminLayer.Models.Exchange GetExchange_ByEmail(string UserEmail)
        {
            return Connector.GetEntity<AdminLayer.Models.Exchange>(this.Connector.CreateProcedureEnumerator("Account.GetExchange_ByEmail",
                                                               new IDataParameter[] {
                                                                        Connector.CreateParameter("Email",UserEmail)}));
        }

        public AdminLayer.Models.Exchange GetExchange_ByGUID(string UserGuid)
        {
            return Connector.GetEntity<AdminLayer.Models.Exchange>(this.Connector.CreateProcedureEnumerator("Account.GetExchange_ByGUID",
                                                               new IDataParameter[] {
                                                                        Connector.CreateParameter("UserGuid",UserGuid)}));
        }
        public long AddUser(AdminLayer.Models.AccountUser NewUser)
        {
            int rowsAffected = 0;
            bool result = false;

            var userID = Connector.GetProcedureResultInt64("Account.AddUser", new IDataParameter[] {
                                                                        Connector.CreateParameter("FirstName",NewUser.FirstName),
                                                                        Connector.CreateParameter("LastName",NewUser.LastName),
                                                                        Connector.CreateParameter("IdentityUserGUID",NewUser.IdentityUserGUID),
                                                                        Connector.CreateParameter("Email",NewUser.Email),
                                                                        Connector.CreateParameter("CultureCode",NewUser.CultureCode),
                                                                        Connector.CreateParameter("ImgURL",NewUser.ImgURL),
                                                                        Connector.CreateParameter("Version",NewUser.Version),
                                                                        Connector.CreateParameter("TimeZoneID",NewUser.TimeZoneID),
                                                                    },
                                                                    out rowsAffected,
                                                                    out result);

            if (result && userID>=0)
            {
                NewUser.UserID = userID;
                return userID;
            }
            else
            {
                return -1;
            }
        }

        public AdminLayer.Models.AccountUser GetUser(long UserID)
        {
            var user = Connector.GetEntity<AdminLayer.Models.AccountUser>(this.Connector.CreateProcedureEnumerator("Account.GetUser",
                                                            new IDataParameter[] {
                                                                        Connector.CreateParameter("UserID",UserID)}));
            return user;
        }

        public bool DeleteUser(long UserID)
        {
            int rowsAffected = 0;
            bool result = false;

            int ResultCode = Connector.GetProcedureResultInt32("Account.DeleteUser", new IDataParameter[] {
                                                                        Connector.CreateParameter("UserID",UserID),
                                                                    },
                                                                    out rowsAffected,
                                                                    out result);

            return result && ResultCode > 0;
        }

        public bool UpdateUser(AdminLayer.Models.AccountUser UpdatedUser)
        {
            int rowsAffected = 0;
            bool result = false;

            int ResultCode = Connector.GetProcedureResultInt32("Account.UpdateUser", new IDataParameter[] {
                                                                        Connector.CreateParameter("FirstName",UpdatedUser.FirstName),
                                                                        Connector.CreateParameter("LastName",UpdatedUser.LastName),
                                                                        Connector.CreateParameter("TimeZoneID",UpdatedUser.TimeZoneID),
                                                                        Connector.CreateParameter("Email",UpdatedUser.Email),
                                                                        Connector.CreateParameter("CultureCode",UpdatedUser.CultureCode),
                                                                        Connector.CreateParameter("ImgURL",UpdatedUser.ImgURL),
                                                                        Connector.CreateParameter("Version",UpdatedUser.Version)
                                                                    },
                                                                    out rowsAffected,
                                                                    out result);

            return result && ResultCode > 0;
        }

        public Models.GlobalizationZone[] GetGlobalizationZones(int? FilterOffset)
        {
            return Connector.GetEntities<AdminLayer.Models.GlobalizationZone>(this.Connector.CreateProcedureEnumerator("Types.GetGlobalizationZones",
                                                            new IDataParameter[] {
                                                                        Connector.CreateParameter("FilterOffset",FilterOffset)}))
                                                                        .ToArray();
        }
        #endregion
    }
}
