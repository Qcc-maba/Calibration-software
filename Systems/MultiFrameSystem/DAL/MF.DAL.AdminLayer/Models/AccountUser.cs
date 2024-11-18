using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models
{
    public class AccountUser
    {
        #region properties
        public long UserID { get; set; }
        public System.DateTime CreationDate { get; set; }
        public System.DateTime? LastLoginDate { get; set; }
        public string IdentityUserGUID { get; set; }
        public string LastToken { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public int TimeZoneID { get; set; }
        public string Email { get; set; }
        public string CultureCode { get; set; }
        public string ImgURL { get; set; }
        public int Version { set; get; }

        #endregion

        #region ctor

        public AccountUser()
        {

        }

        #endregion
    }
}
