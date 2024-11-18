using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Formatting;
using System.Threading;
using System.Threading.Tasks;
using System.Web;
using System.Web.Http;
using System.Web.Http.Filters;

namespace Maba.Hydra2.Systems.Common.CommonWebAPI.MessageHandlers
{
    public class ErrorHandler : ExceptionFilterAttribute
    {
        public JsonMediaTypeFormatter JsonFormatter { get; set; }
        public bool IncludeExceptionDetails { get; set; }

        public override Task OnExceptionAsync(HttpActionExecutedContext actionExecutedContext, CancellationToken cancellationToken)
        {
            return Task.Run(() => OnException(actionExecutedContext));
        }
        public override void OnException(HttpActionExecutedContext actionExecutedContext)
        {

            if (IncludeExceptionDetails)
            {
                var response = new ExceptionDetailsModel()
                {
                    ExceptionType = actionExecutedContext.Exception.GetType().FullName,
                    Message = actionExecutedContext.Exception.Message,
                    StackTrace = actionExecutedContext.Exception.StackTrace
                };
                if (actionExecutedContext.Exception is HttpResponseException)
                {
                    response.Response = (actionExecutedContext.Exception as HttpResponseException).Response.ToString();
                }

                actionExecutedContext.Response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new ObjectContent<ExceptionDetailsModel>(response, JsonFormatter ?? new JsonMediaTypeFormatter())
                };
            }
            else
            {
                var response = new ExceptionModel()
                {
                    ExceptionType = actionExecutedContext.Exception.GetType().FullName,
                    Message = actionExecutedContext.Exception.Message,
                };

                actionExecutedContext.Response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new ObjectContent<ExceptionModel>(response, JsonFormatter ?? new JsonMediaTypeFormatter())
                };
            }
        }
    }
}