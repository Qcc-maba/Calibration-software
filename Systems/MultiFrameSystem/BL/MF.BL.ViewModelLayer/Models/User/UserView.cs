using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.User
{
    public class UserView
    {
        public string Email { get; set; }
        public string AccountUserGUID { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string CultureCode { get; set; }
        public string ImgURL { get; set; }
        public int Version { set; get; }
        public int TimeZoneID { set; get; }

        public UserView()
        {

        }

        public UserView(DAL.AdminLayer.Models.AccountUser user)
        {
            this.Email = user.Email;
            this.AccountUserGUID = user.IdentityUserGUID;
            this.FirstName = user.FirstName;
            this.LastName = user.LastName;
            this.CultureCode = user.CultureCode;
            this.ImgURL = user.ImgURL;
            this.TimeZoneID = user.TimeZoneID;
            this.Version = user.Version;
        }
    }
}
