using Maba.Connectors.InMemoryCache;
using Maba.Connectors.InMemoryCache.StackExchange.Redis;
using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.Online.ClientLibrary
{
    public class Client
    {
        #region properties

        public ClientSettings CurrentSettings { get; private set; }

        #endregion

        #region members

        public JsonSerializerSettings _JsonSettings = null;

        #endregion

        #region ctor

        public Client(ClientSettings settings)
        {
            this.CurrentSettings = settings;

            _JsonSettings = new JsonSerializerSettings();
            _JsonSettings.ContractResolver = new CamelCasePropertyNamesContractResolver();
        }

        #endregion

        #region private methods

        private Newtonsoft.Json.Linq.JToken _CreateEvent<T>(string SN, int EventCode, T e)
        {
            var ev = new Models.GeneralDeviceEvent<T>()
            {
                code = EventCode,
                sn = SN,
                Event = e,
                overview = 0
            };
            /*
            var eventJsonData = Newtonsoft.Json.Linq.JToken.Parse("{}");
            eventJsonData["sn"] = SN;
            eventJsonData["code"] = EventCode.ToString();
            eventJsonData["overview"] = "0";

            eventJsonData["event"] = Newtonsoft.Json.JsonConvert.SerializeObject(ev, _JsonSettings);*/

            return Newtonsoft.Json.JsonConvert.SerializeObject(ev, _JsonSettings);
        }

        private async Task<bool> SendEvent(string SN, int EventCode, object o)
        {
            var eventJsonData = _CreateEvent(SN, EventCode, o);

            var httpClient = new Connectors.HTTPLibrary.HttpClient.HttpClientHelper();
            var result = await httpClient.Post<string, string>($"{CurrentSettings.OnlineServerUrl}/commEvent", eventJsonData.ToString());

            return result == "ok";
        }

        #endregion

        public async Task<bool> SetUnitStatusAsync(string SN, Models.DeviceStatus status)
        {
            return await SendEvent(SN, 1000, status);
        }

        public async Task<Models.DeviceStatus> GetUnitStatusAsync(string SN)
        {
            return null;
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="SN"></param>
        /// <param name="ZoneNumber"></param>
        /// <param name="WatertimeLeft">Seconds</param>
        /// <returns></returns>
        public async Task<Models.DeviceStatus> SetZoneStatusAsync(string SN, int ZoneNumber, int WatertimeLeft)
        {
            return null;
        }

    }
}
