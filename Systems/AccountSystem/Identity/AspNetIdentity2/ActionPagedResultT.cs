using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2
{
    public class ActionPagedResult<T> : ActionResult<T[]>
    {
        public int RequestedPageNumber { get; set; }
        public int RequestedPageSize { get; set; }
        public long TotalItems { get; set; }

        public ActionPagedResult() : base(false)
        {
        }

        public ActionPagedResult(T[] Content) : base(Content)
        {

        }
    }
}
