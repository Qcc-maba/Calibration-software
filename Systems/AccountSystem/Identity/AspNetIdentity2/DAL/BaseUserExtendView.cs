using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.DAL
{
    public class BaseUserExtendView : BaseUser
    {
        public string Temperature_UnitView { get; set; }
        public string Temperature_DisplayName { get; set; }
        public string CultureCode { get; set; }

        public BaseUserExtendView()
        {

        }
    }
}
