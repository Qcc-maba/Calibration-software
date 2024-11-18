using Microsoft.Owin.Security.DataProtection;
using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.OWINLibrary.Cryptography
{
    public static class DataProtectorExtensions
    {
        #region private

        private static JsonSerializerSettings GetJsonSettings()
        {
            var jsonSettings = new JsonSerializerSettings()
            {
                Formatting = Formatting.None
            };

            return jsonSettings;
        }

        #endregion

        #region public Protect/UnProtect

        public static string ASCIIProtect(this IDataProtector dataProtector, string unprotectedData)
        {
            var unprotectedBuffer = System.Text.UTF8Encoding.UTF8.GetBytes(unprotectedData);
            var protectedBuffer = dataProtector.Protect(unprotectedBuffer);

            return Convert.ToBase64String(protectedBuffer);
        }

        public static string ASCIIUnprotect(this IDataProtector dataProtector, string protectedDataBase64)
        {
            var protectedData = Convert.FromBase64String(protectedDataBase64);
            var unprotectedBuffer = dataProtector.Unprotect(protectedData);

            return System.Text.UTF8Encoding.UTF8.GetString(unprotectedBuffer);
        }

        public static T ObjectUnprotect<T>(this IDataProtector dataProtector, string protectedData)
        {
            var unprotectedData = ASCIIUnprotect(dataProtector, protectedData);
            return JsonConvert.DeserializeObject<T>(unprotectedData, GetJsonSettings());
        }

        public static string ObjectProtect(this IDataProtector dataProtector, object unprotectedData)
        {
            var json_str = JsonConvert.SerializeObject(unprotectedData, GetJsonSettings());
            return ASCIIProtect(dataProtector, json_str);
        }

        #endregion
    }
}
