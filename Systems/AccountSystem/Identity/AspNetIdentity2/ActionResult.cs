using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2
{
    public class ActionResult
    {
        private static readonly ActionResult _success = new ActionResult(true);

        #region static properties

        public static ActionResult Success
        {
            get { return _success; }
        }

        #endregion

        #region properties

        public IEnumerable<string> Errors { get; private set; }
        public bool Succeeded { get; private set; }

        #endregion

        #region ctor

        public ActionResult(bool success, params string[] errors)
        {
            Succeeded = success;

            if (errors != null && errors.Length > 0)
            {
                Errors = errors;
            }
            else
            {
                Errors = new string[0];
            }
        }

        public ActionResult(params string[] errors)
            : this(false, errors)
        {
        }

        #endregion
    }
}
