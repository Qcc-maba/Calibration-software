using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using System.IO;
using System.Collections.Specialized;

namespace Maba.Connectors.HTTPLibrary.HttpClient
{
    public class HttpClientHelper
    {
        public Action<JsonSerializer> JsonSerializerSettings { get; set; }
        public NameValueCollection RequestHeaders { get; set; }

        #region private methods

        private void handleHeaders(WebClient client)
        {
            if (RequestHeaders != null && RequestHeaders.Count > 0)
            {
                client.Headers.Add(RequestHeaders);
            }
        }

        #endregion

        #region HTTP methods

        public async Task<T> Post<T, K>(string uri, K Data)
        {
            return await UploadData<T, K>(uri, "POST", Data);
        }

        public async Task<T> UploadData<T, K>(string uri, string method, K Data, string ContentType = "application/json")
        {
            using (var client = new WebClient())
            {
                //Headers
                handleHeaders(client);

                client.Headers.Add(HttpRequestHeader.ContentType, ContentType);

                byte[] dataDownloaded = null;
                if (Data == null)
                {
                    dataDownloaded = await client.UploadDataTaskAsync(new Uri(uri), method, new byte[0]);

                }
                else
                {
                    byte[] data_bytes = null;
                    if (typeof(K) == typeof(string))
                    {
                        data_bytes = System.Text.UTF8Encoding.UTF8.GetBytes(Data as string);
                    }
                    else
                    {
                        var data_str = Newtonsoft.Json.Linq.JObject.FromObject(Data).ToString();
                        data_bytes = System.Text.UTF8Encoding.UTF8.GetBytes(data_str);
                    }
                    dataDownloaded = await client.UploadDataTaskAsync(new Uri(uri), method, data_bytes);
                }

                if (typeof(T) == typeof(string))
                {
                    return (T)Convert.ChangeType(System.Text.UTF8Encoding.UTF8.GetString(dataDownloaded), typeof(T));
                }
                else
                {
                    return JsonConvert.DeserializeObject<T>(System.Text.UTF8Encoding.UTF8.GetString(dataDownloaded));
                }
            }
        }

        public async Task<string> UploadData(string uri, string method, string Data, string ContentType = "application/json")
        {
            using (var client = new WebClient())
            {
                //Headers
                handleHeaders(client);

                client.Headers.Add(HttpRequestHeader.ContentType, ContentType);

                byte[] dataDownloaded = null;
                if (Data == null)
                {
                    dataDownloaded = await client.UploadDataTaskAsync(new Uri(uri), method, new byte[0]);
                }
                else
                {
                    var data_str = Newtonsoft.Json.Linq.JObject.FromObject(Data).ToString();
                    var data_bytes = System.Text.UTF8Encoding.UTF8.GetBytes(data_str);
                    dataDownloaded = await client.UploadDataTaskAsync(new Uri(uri), method, data_bytes);
                }

                return System.Text.UTF8Encoding.UTF8.GetString(dataDownloaded);
            }
        }

        public async Task<T> Get<T>(string uri)
        {
            using (var client = new WebClient())
            {
                //Headers
                handleHeaders(client);

                var streamResponse = await client.OpenReadTaskAsync(new Uri(uri));

                using (StreamReader streamReader = new StreamReader(streamResponse))
                {
                    var serializer = new JsonSerializer();
                    if (JsonSerializerSettings != null)
                    {
                        JsonSerializerSettings(serializer);
                    }

                    return (T)serializer.Deserialize(streamReader, typeof(T));
                }
            }
        }

        public async Task<string> Get(string uri)
        {
            using (var client = new WebClient())
            {
                //Headers
                handleHeaders(client);

                var response = await client.DownloadStringTaskAsync(new Uri(uri));

                return response;
            }
        }

        #endregion
    }
}
