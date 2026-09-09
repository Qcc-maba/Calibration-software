using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.DAL.BaseDAL;

namespace ComServerBL.Hydra2.DAL.CNF
{
    public class CNFRepository : Maba.DAL.BaseDAL.BaseConnector
    {
        #region CONSTANTS

        public const string DEFAULT_STRING_CONNECTION_NAME = "CommServer.Hydra2.CNF";

        #endregion

        #region ctor

        public CNFRepository()
            : base(DEFAULT_STRING_CONNECTION_NAME)
        {

        }

        public CNFRepository(string stringConnectionSectionName)
            : base(stringConnectionSectionName)
        {
        }

        #endregion

        #region Get Models

        public Models.ZoneSettings[] GetZones(long ConfigID)
        {

            var zones = this.Connector.GetEntities<Models.ZoneSettings>(
                this.Connector.CreateProcedureEnumerator("ComServer.GetZones",
                                                new System.Data.IDataParameter[]
                                                {
                                                    this.Connector.CreateParameter("ConfigID",ConfigID)
                                                })
                );


            return zones
                .ToArray();
        }

        #endregion
    }
}
