using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Xml.Serialization;

namespace Maba.Connectors.SMSServices
{
    [XmlInclude(typeof(Connectors.NexmoClientSettings))]
    public class SMSServiceSettings
    {
        #region properties

        public string ConnectorType { get; set; } = "None";
        public bool InEnabled { get; set; }

        public int Timeout { get; set; }
        /// <summary>
        ///     The twilio default sender name (textual, alphanumerical only)
        /// </summary>
        public string DefaultSenderName { get; set; }

        public List<KeyValuePair<string, string>> Keys { get; set; }

        #endregion

        #region ctor

        public SMSServiceSettings()
        {
            Timeout = 5000;
            InEnabled = false;

            Keys = new List<KeyValuePair<string, string>>();
            Keys.Add(new KeyValuePair<string, string>("DemoKey", "DemoValue"));

            DefaultSenderName = "Maba";
        }

        #endregion

        #region public methods

        public void AddKey(string key, string value)
        {
            this.Keys.Add(new KeyValuePair<string, string>(key, value));
        }

        public string GetKeyValue(string key, string defaultValue = null)
        {
            for (int i = 0; i < this.Keys.Count; i++)
            {
                if (this.Keys[i].Key == key)
                {
                    return this.Keys[i].Value;
                }
            }

            return defaultValue;
        }

        #endregion

        #region static methods

        public static ISMSSenderConnector Create(SMSServiceSettings settings)
        {
            switch (settings.ConnectorType)
            {
                case Connectors.NexmoClientConnector.CONNECTOR_TYPE:
                    return new Connectors.NexmoClientConnector(settings);
                    // break;
            }

            return null;
        }

        #endregion
    }
}
