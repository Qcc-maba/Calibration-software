using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.UserManager
{
    public class UserClaim
    {
        #region properties

        private long _UserID = -1;
        public long UserID
        {
            get
            { return _UserID; }
            set
            {
                _UserID = value;
                _UserId = value.ToString();
            }
        }

        private string _UserId = "";
        public string UserId
        {
            get
            { return _UserId; }
            set
            {
                _UserId = value;
                UserID = long.Parse(value);
            }
        }

        public long Id { get; set; }
        public string ClaimValue { get; set; }
        public string ClaimType { get; set; }

        #endregion

        #region ctor(s)

        public UserClaim()
        {

        }

        #endregion
    }
}
