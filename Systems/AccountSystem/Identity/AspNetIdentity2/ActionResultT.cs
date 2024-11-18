using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2
{
    public class ActionResult<T> : ActionResult
    {
        public T Result { get; set; }

        public ActionResult(bool success, params string[] errors)
            : base(success, errors)
        {

        }

        public ActionResult(T result)
            : base(true)
        {
            Result = result;
        }
    }
}
