using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.DAL
{
    public class BaseUser
    {
        public long UserID { get; set; }

        public DateTime CreationDate { get; set; }
        public DateTime UpdateDate { get; set; }

        public string UserName { get; set; }
        public DateTime? LastLoginDateUtc { get; set; }
        public DateTime? LastFailedLoginDateUtc { get; set; }
        public string UserGuid { get; set; }
        public string Email { get; set; }
        public bool EmailConfirmed { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string PasswordHash { get; set; }
        public string PhoneNumber { get; set; }
        public bool PhoneConfirmed { get; set; }
        public bool LockoutEnabled { get; set; }
        public DateTime? LockoutEndDateUtc { get; set; }
        public int AccessFailedCount { get; set; }
        public string SecurityStamp { get; set; }
        public string ImgURL { get; set; }
        public int UpdateVersion { get; set; }
        public int UIFormatID { get; set; }
        //Custom Long-Date-Pattern, override pattern in selected UIFormatID 
        public string LongDatePattern { get; set; }
        //Custom Short-Date-Pattern, override pattern in selected UIFormatID 
        public string ShortDatePattern { get; set; }
        //Custom Short-Time-Pattern, override pattern in selected UIFormatID 
        public string ShortTimePattern { get; set; }
        //Custom Long-Time-Pattern, override pattern in selected UIFormatID 
        public string LongTimePattern { get; set; }
        public int TimeZoneID { get; set; }
        public string TimeZoneSystemID { get; set; }
        public int TimeZoneGMTOffset { get; set; }
        public int TemperatureUnitID { get; set; }
        public string City { get; set; }
        public string Country { get; set; }
        public string StreetName { get; set; }
        public int StreetNo { get; set; }
        public string ZipCode { get; set; }

        public BaseUser()
        {

        }
    }
}
