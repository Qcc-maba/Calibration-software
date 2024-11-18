using Maba.Connectors.HTTPLibrary.HttpClient;
using Maba.Connectors.JsonHelpersLibrary.Converters;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http.Headers;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.WebServices.Controllers.Models
{
    public class ApplicationUserModel
    {
        #region properties
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

        #endregion

        #region ctor

        public ApplicationUserModel()
        {

        }

        #endregion

        public static async Task<Common.CommonWebAPI.Models.Response<ApplicationUserModel>> GetUserProfile(string AccountSystemUri, AuthenticationHeaderValue Authorization)
        {
            try
            {
                var uri = $"{AccountSystemUri}/Account/Profile/Full";
                var d = new DateTimeUNIXConvertor();

                var client = new HttpClientHelper()
                {
                    JsonSerializerSettings = (serializer) => serializer.Converters.Add(new DateTimeUNIXConvertor())
                };

                client.RequestHeaders = new System.Collections.Specialized.NameValueCollection();
                client.RequestHeaders.Add("Authorization", $"{Authorization.Scheme} {Authorization.Parameter}");

                var result = await client.Get<Common.CommonWebAPI.Models.Response<ApplicationUserModel>>(uri);

                return result;
            }
            catch
            {
                return new Common.CommonWebAPI.Models.Response<ApplicationUserModel>()
                {
                    Result = false
                };
            }
        }
    }
}
