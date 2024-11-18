using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.DAL.BaseDAL
{
    public class TesterConnector : BaseConnector
    {
        #region ctor(s)

        private void initCtor()
        {
            this.ThrowExceptions = true;
        }


        public TesterConnector(string providerName, string stringConnection)
            : base(providerName, stringConnection)
        {
            initCtor();
        }

        public TesterConnector(string stringConnectionSectionName)
            : base(stringConnectionSectionName)
        {
            initCtor();
        }

        #endregion

    }
}
