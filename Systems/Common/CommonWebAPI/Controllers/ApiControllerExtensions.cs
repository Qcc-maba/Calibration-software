using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Formatting;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;
using System.Web.Http;
using JsonHelpersLibrary = Maba.Connectors.JsonHelpersLibrary;

namespace Maba.Hydra2.Systems.Common.CommonWebAPI.Controllers
{
    public static class ApiControllerExtensions
    {
        #region accessories

        public static object GetCurrentIdentityUser(this ApiController controller)
        {
            var identity = controller.User.Identity as ClaimsIdentity;

            return JsonHelpersLibrary.JSONPrinter.Print(identity);
        }

        #endregion

        #region public static methods

        /* public static Models.Response<T> ConvertException<T>(Exception e)
         {
             return new Models.Response<T>()
             {
                 Messages = ConvertException(e).Messages,
                 Result = false
             };
         }*/

        /* public static Models.Response ConvertException(Exception e)
         {
             if (e is System.Data.SqlClient.SqlException)
             {
                 var eSQL = e as System.Data.SqlClient.SqlException;
                 return new Models.Response()
                 {
                     Messages = new Models.MessageCodeModel[] { new Models.MessageCodeModel(eSQL.Number, e.Message) }
                 };
             }
             else
             {
                 return new Models.Response()
                 {
                     Messages = new Models.MessageCodeModel[] { new Models.MessageCodeModel(e.Message) },
                     Result = false
                 };
             }
         }*/

        #endregion

        #region Handling requests

        private static Exception _HandleException(Exception e)
        {
            if (e is Errors.SecurityException)
            {
                var eSE = e as Errors.SecurityException;
                return ThrowHttpResponseException(null, new Models.MessageCodeModel[]
                                                                    {
                                                                                        new Models.MessageCodeModel(eSE.Code, eSE.Message)
                                                                    },
                                                                    HttpStatusCode.Forbidden);
            }
            else if (e.GetType().Name.Contains("SecurityException"))
            {
                return ThrowHttpResponseException(null, null, HttpStatusCode.Forbidden);
            }
            else if (e is HttpResponseException)
            {
                return e;
            }
            else if (e is System.Data.SqlClient.SqlException)
            {
                var eSQL = e as System.Data.SqlClient.SqlException;

                return ThrowHttpResponseException(null, new Models.MessageCodeModel[]
                                                                                    {
                                                                                        new Models.MessageCodeModel(eSQL.Number, e.Message)
                                                                                    },
                                                                                    HttpStatusCode.BadRequest);
            }
            else
            {
                return e;
            }
        }

        public static Models.Response<T> HandleResponse<T>(this ApiController controller, Func<T> fun, Func<bool> TestedCondition = null)
        {
            try
            {
                var response = fun();

                if (typeof(T).IsClass && response == null)
                {
                    return new Models.Response<T>()
                    {
                        Result = false
                    };
                }

                if (TestedCondition != null && !TestedCondition())
                {
                    return new Models.Response<T>()
                    {
                        Result = false
                    };
                }

                return new Models.Response<T>()
                {
                    Result = true,
                    Body = response
                };
            }
            catch (Exception e)
            {
                throw _HandleException(e);
            }
        }

        public static Models.Response HandleResponse(this ApiController controller, Action fun)
        {
            try
            {
                fun();

                return new Models.Response()
                {
                    Result = true
                };
            }
            catch (Errors.SecurityException e)
            {
                return new Models.Response()
                {
                    Messages = new Models.MessageCodeModel[] { new Models.MessageCodeModel(e.Code, e.Message) },
                    Result = false
                };
            }
            catch (Exception e)
            {
                throw _HandleException(e);
            }
        }

        public static async Task<Models.Response> HandleResponseTask(this ApiController controller, Func<Task<Models.Response>> fun, Func<bool> TestedCondition = null)
        {
            try
            {
                var response = await fun();

                if (TestedCondition != null && !TestedCondition())
                {
                    return new Models.Response()
                    {
                        Result = false
                    };
                }

                return response;
            }
            catch (Exception e)
            {
                throw _HandleException(e);
            }
        }

        public static async Task<Models.Response<T>> HandleResponseTask<T>(this ApiController controller, Func<Task<Models.Response<T>>> fun, Func<bool> TestedCondition = null)
        {
            try
            {
                var response = await fun();

                if (typeof(T).IsClass && response == null)
                {
                    return new Models.Response<T>()
                    {
                        Result = false
                    };
                }

                if (TestedCondition != null && !TestedCondition())
                {
                    return new Models.Response<T>()
                    {
                        Result = false
                    };
                }

                return response;
            }
            catch (Exception e)
            {
                throw _HandleException(e);
            }
        }

        public static async Task<Models.PagedResponse<T>> HandlePagedResponseTask<T>(this ApiController controller, Func<Task<Models.PagedResponse<T>>> fun, Func<bool> TestedCondition = null)
        {
            try
            {
                var response = await fun();

                if (typeof(T).IsClass && response == null)
                {
                    return new Models.PagedResponse<T>()
                    {
                        Result = false
                    };
                }

                if (TestedCondition != null && !TestedCondition())
                {
                    return new Models.PagedResponse<T>()
                    {
                        Result = false
                    };
                }

                return response;
            }
            catch (Exception e)
            {
                throw _HandleException(e);
            }
        }


        public static Exception ThrowHttpResponseException(this ApiController controller, Models.MessageCodeModel[] messages = null, HttpStatusCode code = HttpStatusCode.BadRequest)
        {
            var response = new Models.Response()
            {
                Messages = messages,
                Result = false
            };

            var jsonFormatter = controller == null ? new JsonMediaTypeFormatter() { Indent = true } : controller.RequestContext.Configuration.Formatters.JsonFormatter;

            return new HttpResponseException(new HttpResponseMessage(code)
            {
                Content = new ObjectContent<Models.Response>(response, jsonFormatter)
            });
        }

        public static void ValidateArguments(this ApiController controller, params object[] args)
        {
            if (args == null || args.Any(a => a == null))
            {
                throw ThrowHttpResponseException(controller, new CommonWebAPI.Models.MessageCodeModel[]
                                                        {
                                                        new CommonWebAPI.Models.MessageCodeModel(0, "One or more parameters is/are empty/invalid !")
                                                        },
                                                        HttpStatusCode.BadGateway);
            }
        }

        #endregion
    }
}
