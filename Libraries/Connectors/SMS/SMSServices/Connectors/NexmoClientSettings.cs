using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.SMSServices.Connectors
{
    public class NexmoClientSettings
    {
        #region CONSTANTS

        public static readonly string DefaultGatewayAddress = "https://rest.nexmo.com/sms/json?api_key={0}&api_secret={1}&from={2}&to={3}&text={4}&type=unicode";
        public static readonly string KEY__API_KEY = "ApiKey";
        public static readonly string KEY__API_SECRET = "ApiSecret";
        public static readonly string KEY__CUSTOM_GATEWAT_ADDRESS = "CustomGatewayAddress";

        #endregion

        #region properties

        public string CustomGatewayAddress { get; private set; }

       /// <summary>
        ///     The Nexmo default api key
        ///     Account :: https://dashboard.nexmo.com/login, relip@Maba.co.il ,reli032616831
        /// </summary>
        public string ApiKey { get; private set; }

        /// <summary>
        ///     The Nexmo default api secret key
        /// </summary>
        public string ApiSecret { get; private set; }

        public SMSServiceSettings BaseSettings { get; private set; }

        #endregion

        public NexmoClientSettings(SMSServiceSettings _settings)
        {
            BaseSettings = _settings;

            this.ApiSecret = BaseSettings.GetKeyValue(KEY__API_SECRET);
            this.ApiKey = _settings.GetKeyValue(KEY__API_KEY);
            this.CustomGatewayAddress = _settings.GetKeyValue(KEY__CUSTOM_GATEWAT_ADDRESS);
        }
    }
}
