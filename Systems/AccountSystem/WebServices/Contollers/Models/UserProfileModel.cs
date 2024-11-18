using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.WebServices.Contollers.Models
{
    public class UserProfileModel
    {
        public DateTime CreationDate { get; set; }
        public DateTime UpdateDate { get; set; }
        public DateTime? LastLoginDateUtc { get; set; }
        public DateTime? LastFailedLoginDateUtc { get; set; }
        public string Email { get; set; }
        public string UserGuid { get; set; }
        public string CultureCode { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string Phone { get; set; }
        public bool IsPhoneConfirmed { get; set; }
        public string City { get; set; }
        public string Country { get; set; }
        public string StreetName { get; set; }
        public int StreetNo { get; set; }
        public string ZipCode { get; set; }
        public string LongDatePattern { get; set; }
        public string ShortDatePattern { get; set; }
        public string ShortTimePattern { get; set; }
        public string LongTimePattern { get; set; }
        public int ActualOffset { get; set; }
        public int UIFormatID { get; set; }
        public int TimeZoneID { get; set; }
        public int TemperatureUnitID { get; set; }
        public string ImgURL { get; set; }

        public string Temperature_UnitView { get; set; }
        public string Temperature_DisplayName { get; set; }

        public UserProfileModel()
        {

        }

        public UserProfileModel(AspNetIdentity.Identity2.BL.Models.ApplicationUserModel user, string CorrectedImageURL)
        {
            UserGuid = user.UserGuid;

            Email = user.Email;
            FirstName = user.FirstName;
            LastName = user.LastName;
            Phone = user.PhoneNumber;
            CultureCode = user.CultureCode;
            ActualOffset = user.Get_ActualOffset();
            City = user.City;
            Country = user.Country;
            StreetName = user.StreetName;
            StreetNo = user.StreetNo;
            ZipCode = user.ZipCode;
            ImgURL = CorrectedImageURL;
            LongDatePattern = user.LongDatePattern;
            ShortDatePattern = user.ShortDatePattern;
            ShortTimePattern = user.ShortTimePattern;
            LongTimePattern = user.LongTimePattern;
            TimeZoneID = user.TimeZoneID;
            UIFormatID = user.UIFormatID;
            TemperatureUnitID = user.TemperatureUnitID;
            IsPhoneConfirmed = user.PhoneConfirmed;
            CreationDate = user.CreationDate;
            LastFailedLoginDateUtc = user.LastFailedLoginDateUtc;
            LastLoginDateUtc = user.LastLoginDateUtc;
            Temperature_DisplayName = user.Temperature_DisplayName;
            Temperature_UnitView = user.Temperature_UnitView;
            UpdateDate = user.UpdateDate;
        }

    }
}
