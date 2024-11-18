using System;
using System.Collections.Generic;
using System.Data.Common;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.DAL.BaseDAL
{
    public class BaseConnector : IDisposable
    {
        #region public properties

        public BaseDALConnector Connector { get; private set; }
        public bool ThrowExceptions
        {
            get
            {
                if (this.Connector != null)
                {
                    return this.Connector.ThrowExceptions;
                }

                return false;
            }
            set
            {
                if (this.Connector != null) 
                {
                    this.Connector.ThrowExceptions = value;
                }
            }
        }

        #endregion

        #region ctor (s)

        private BaseConnector()
        {
            ThrowExceptions = true;
        }

        public BaseConnector(Connection connection)
            : this()
        {
            Connector = BaseDALConnector.Create(connection.ProviderName, connection.ConnectionString);
        }

        public BaseConnector(string providerName, string stringConnection)
            : this()
        {
            Connector = BaseDALConnector.Create(providerName, stringConnection);
        }

        public BaseConnector(string stringConnectionSectionName)
            : this()
        {
            Connector = BaseDALConnector.Create(stringConnectionSectionName);
        }

        #endregion

        #region IDisposable

        public virtual void Dispose()
        {
            if (Connector != null && !Connector.IsDisposed)
            {
                Connector.Dispose();
            }
        }

        #endregion
    }
}
