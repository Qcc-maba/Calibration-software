using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.BL.Models
{
    public class UpdateUserModel
    {
        #region properties

        public string Email { get; set; }

        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string PhoneNumber { get; set; }

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
        public int TemperatureUnitID { get; set; }
        public string City { get; set; }
        public string Country { get; set; }
        public string StreetName { get; set; }
        public int StreetNo { get; set; }
        public string ZipCode { get; set; }

        #endregion

        public UpdateUserModel()
        {

        }

        public UpdateUserModel(ApplicationUserModel user)
        {
            //public 
            this.Email = user.Email;
            this.City = user.City;
            this.Country = user.Country;
            this.FirstName = user.FirstName;
            this.LastName = user.LastName;
            this.LongDatePattern = user.LongDatePattern;
            this.LongTimePattern = user.LongTimePattern;
            this.ShortDatePattern = user.ShortDatePattern;
            this.ShortTimePattern = user.ShortTimePattern;
            this.StreetName = user.StreetName;
            this.StreetNo = user.StreetNo;
            this.TemperatureUnitID = user.TemperatureUnitID;
            this.TimeZoneID = user.TimeZoneID;
            this.UIFormatID = user.UIFormatID;
            this.ZipCode = user.ZipCode;
        }

    }
}
