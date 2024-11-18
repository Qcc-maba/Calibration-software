using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using System.Web;

namespace Maba.Hydra2.Systems.MF.WebServices.MessageHandlers
{
    public class ErrorHandler : DelegatingHandler
    {
        protected async override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken
                                     cancellationToken)
        {
            try
            {
                var response = await base.SendAsync(request,
                                                    cancellationToken);

                return response;
            }
            catch (Exception ex)
            {
                var responseMessage =
                    request.CreateResponse(
                        HttpStatusCode.InternalServerError,
                        ex);
                return responseMessage;
            }
        }
    }
}