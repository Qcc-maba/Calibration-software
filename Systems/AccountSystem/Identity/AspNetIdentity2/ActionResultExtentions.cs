using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2
{
    public static class ActionResultExtentions
    {
        public static bool ValidateSuccess(this ActionResult result)
        {
            return result != null && result.Succeeded;
        }
    }
}
