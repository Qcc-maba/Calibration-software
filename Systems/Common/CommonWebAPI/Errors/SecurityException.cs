using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.Common.CommonWebAPI.Errors
{
    public class SecurityException : Exception
    {
        #region properties

        public int Code { get; set; }

        #endregion

        #region ctor

        public SecurityException()
        {

        }

        public SecurityException(string message, int Code)
            : base(message)
        {

        }

        #endregion
    }

}
