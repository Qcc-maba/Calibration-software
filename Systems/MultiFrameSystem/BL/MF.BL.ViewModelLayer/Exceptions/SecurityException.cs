using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Exceptions
{
    public class SecurityException : Exception
    {
        #region CONSTANTS

        public const int EXCEPTION_ADMIN = 301;
        public const int EXCEPTION_VIEW = 302;
        public const int EXCEPTION_MODIFY = 303;
        public const int EXCEPTION_SECURITY = 304;
        public const int EXCEPTION_TRANSFER = 50005;

        #endregion

        #region properties

        public int Code { get; set; }

        #endregion

        #region ctor(s)

        public SecurityException()
        {

        }

        public SecurityException(string message, int _Code)
            : base(message)
        {
            Code = _Code;
        }

        #endregion
    }
}
