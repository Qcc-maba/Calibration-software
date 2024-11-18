using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using System.Web;

namespace Maba.Hydra2.Systems.Common.CommonWebAPI.MessageHandlers
{
    public class MessageSnifferHandler : DelegatingHandler
    {
        protected async override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            //Before
            Debug.WriteLine("****Request*****");
            Debug.WriteLine("Incoming Request {0}::{1}", request.Method, request.RequestUri);
            Debug.WriteLine("\tHeaders: {0}", request.Headers.Count());
            var requestContent = await request.Content.ReadAsStringAsync();
            Debug.WriteLine("\t{0}", requestContent);

            // Call the inner handler.
            var response = await base.SendAsync(request, cancellationToken);

            //After
            Debug.WriteLine("****Reponse*****");
            Debug.WriteLine("\tResponse: StatusCode:{0}", response.StatusCode);
            var responseContent = await request.Content.ReadAsStringAsync();

            Debug.WriteLine("\tResponse: Content:{0}", responseContent);

            Debug.WriteLine("\t{0}", await request.Content.ReadAsStringAsync());
            Debug.WriteLine("****End*****");

            return response;
        }
    }
}