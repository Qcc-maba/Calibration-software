using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using System.Web;
using System.Web.Http;

namespace Maba.AccountSystem.WebServices.HttpActionResults
{
    public class RedirectExternalLoginResult : IHttpActionResult
    {
        #region properties

        public string RedirectURI { get; set; }
        public NameValueCollection AdditionalQueryParams { get; set; }

        #endregion

        #region ctor

        public RedirectExternalLoginResult(string redirectURI)
        {
            RedirectURI = redirectURI;
            AdditionalQueryParams = new NameValueCollection();
        }

        #endregion

        #region private methods

        private HttpResponseMessage Execute()
        {
            HttpResponseMessage response = new HttpResponseMessage(HttpStatusCode.Redirect);

            try
            {
                response.Headers.Location = CreateRedirectUri();
            }
            catch
            {
                response.Dispose();
                throw;
            }

            return response;
        }

        //private string ToQueryString()
        //{
        //    foreach (var k in AdditionalQueryParams.AllKeys)
        //    {

        //    }
        //    var array = (from key in AdditionalQueryParams.AllKeys
        //                 from value in AdditionalQueryParams.GetValues(key)
        //                 select string.Format("{0}={1}", HttpUtility.UrlEncode(key), HttpUtility.UrlEncode(value)))
        //        .ToArray();
        //    return string.Join("&", array);
        //}

        public Uri CreateRedirectUri()
        {
            UriBuilder uriBuilder = new UriBuilder(RedirectURI);
            var query = uriBuilder.Uri.ParseQueryString();

            foreach (var k in AdditionalQueryParams.AllKeys)
            {
                query[k] = AdditionalQueryParams[k];
            }
            uriBuilder.Query = query.ToString();
            return uriBuilder.Uri;
        }

        #endregion

        #region IHttpActionResult members

        public System.Threading.Tasks.Task<System.Net.Http.HttpResponseMessage> ExecuteAsync(System.Threading.CancellationToken cancellationToken)
        {
            return Task.FromResult<HttpResponseMessage>(Execute());
        }

        #endregion
    }
}