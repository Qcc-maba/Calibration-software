using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.BL.Models
{
    public class ApplicationUserModel
    {
        #region properties
        public DateTime CreationDate { get; set; }
        public DateTime UpdateDate { get; set; }
        public DateTime? LastLoginDateUtc { get; set; }
        public DateTime? LastFailedLoginDateUtc { get; set; }

        public int UpdateVersion { get; set; }
        public string UserGuid { get; set; }
        public string Email { get; set; }
        public bool EmailConfirmed { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string PhoneNumber { get; set; }
        public bool PhoneConfirmed { get; set; }
        public bool LockoutEnabled { get; set; }
        public DateTime? LockoutEndDateUtc { get; set; }
        public int AccessFailedCount { get; set; }
        public string ImgURL { get; set; }
        public int UIFormatID { get; set; }
        public string CultureCode { get; set; }
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
        public string Temperature_UnitView { get; set; }
        public string Temperature_DisplayName { get; set; }
        public string City { get; set; }
        public string Country { get; set; }
        public string StreetName { get; set; }
        public int StreetNo { get; set; }
        public string ZipCode { get; set; }

        #region internals

        internal long UserID { get; private set; }
        internal string SecurityStamp { get; private set; }
        internal string UserName { get; set; }

        #endregion

        #endregion

        private int _TimeZoneGMTOffset = 0;
        private string _TimeZoneSystemID = null;


        #region ctor

        public ApplicationUserModel()
        {

        }

        public ApplicationUserModel(DAL.BaseUserExtendView userExtended)
        {
            //keep private
            _TimeZoneGMTOffset = userExtended.TimeZoneGMTOffset;
            _TimeZoneSystemID = userExtended.TimeZoneSystemID;


            //public properties
            this.UserID = userExtended.UserID;
            this.SecurityStamp = userExtended.SecurityStamp;
            this.UserName = userExtended.UserName;

            this.LastLoginDateUtc = userExtended.LastLoginDateUtc;
            this.LastFailedLoginDateUtc = userExtended.LastFailedLoginDateUtc;

            this.AccessFailedCount = userExtended.AccessFailedCount;
            this.City = userExtended.City;
            this.Country = userExtended.Country;
            this.CreationDate = userExtended.CreationDate;
            this.CultureCode = userExtended.CultureCode;
            this.Email = userExtended.Email;
            this.EmailConfirmed = userExtended.EmailConfirmed;
            this.FirstName = userExtended.FirstName;
            this.ImgURL = userExtended.ImgURL;
            this.LastName = userExtended.LastName;
            this.LockoutEnabled = userExtended.LockoutEnabled;
            this.LockoutEndDateUtc = userExtended.LockoutEndDateUtc;
            this.LongDatePattern = userExtended.LongDatePattern;
            this.LongTimePattern = userExtended.LongTimePattern;
            this.PhoneConfirmed = userExtended.PhoneConfirmed;
            this.PhoneNumber = userExtended.PhoneNumber;
            this.ShortTimePattern = userExtended.ShortTimePattern;
            this.StreetName = userExtended.StreetName;
            this.StreetNo = userExtended.StreetNo;
            this.TemperatureUnitID = userExtended.TemperatureUnitID;
            this.Temperature_DisplayName = userExtended.Temperature_DisplayName;
            this.Temperature_UnitView = userExtended.Temperature_UnitView;
            this.TimeZoneID = userExtended.TimeZoneID;
            this.UIFormatID = userExtended.UIFormatID;
            this.UpdateDate = userExtended.UpdateDate;
            this.UpdateVersion = userExtended.UpdateVersion;
            this.UserGuid = userExtended.UserGuid;
            this.ZipCode = userExtended.ZipCode;
        }

        #endregion

        public long Get_UserID()
        {
            return UserID;
        }
        public string Get_UserName()
        {
            return UserName;
        }
        public string Get_SecurityStamp()
        {
            return SecurityStamp;
        }

        public int Get_ActualOffset()
        {
            if (String.IsNullOrEmpty(_TimeZoneSystemID))
            {
                var _actualOffset = SystemTimeZoneModel.CalculateActualOffset(_TimeZoneSystemID, _TimeZoneGMTOffset);

                return _actualOffset;
            }
            else
            {
                return 0;
            }
        }
    }
}

