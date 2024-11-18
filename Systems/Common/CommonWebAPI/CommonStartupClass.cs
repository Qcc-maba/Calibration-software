using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Web.Http;
using Microsoft.Owin.Security.OAuth;
using Newtonsoft.Json.Serialization;
using System.Web.Http.Cors;
using System.Threading.Tasks;
using System.Diagnostics;
using System.Threading;
using System.Net.Http.Formatting;
using JsonHelpersLibrary = Maba.Connectors.JsonHelpersLibrary;

namespace Maba.Hydra2.Systems.Common.CommonWebAPI
{
    public static class CommonWebApiConfig
    {
        public static bool DebugMode { get; set; } = false;
        public static void Register1(HttpConfiguration config)
        {
            #region Cors

            var cors = new EnableCorsAttribute("*", "*", "*");
            config.EnableCors(cors);

            #endregion

            #region authentication

            // Web API configuration and services
            // Configure Web API to use only bearer token authentication.
            config.SuppressDefaultHostAuthentication();

            #endregion

            #region Formatters

            var jsonFormatter = new JsonMediaTypeFormatter();
            jsonFormatter.Indent = true;

            if (DebugMode)
            {
                config.Formatters.Clear();
                config.Formatters.Add(jsonFormatter);
            }

            config.Formatters.JsonFormatter.SerializerSettings.Converters.Add(new JsonHelpersLibrary.Converters.DateTimeUNIXConvertor());
            config.Formatters.JsonFormatter.SerializerSettings.ContractResolver = new CamelCasePropertyNamesContractResolver();
            config.Filters.Add(new HostAuthenticationFilter(OAuthDefaults.AuthenticationType));

            #endregion

            #region Handlers

            config.IncludeErrorDetailPolicy = IncludeErrorDetailPolicy.Never;
            config.Filters.Add(new MessageHandlers.ErrorHandler() { IncludeExceptionDetails = DebugMode, JsonFormatter = jsonFormatter });

            if (DebugMode)
            {
                config.MessageHandlers.Add(new MessageHandlers.MessageSnifferHandler());
            }

            #endregion

            #region Routes

            config.MapHttpAttributeRoutes();

            //No Thanks!
            /*config.Routes.MapHttpRoute(
                name: "DefaultApi",
                routeTemplate: "api/{controller}/{id}",
                defaults: new { id = RouteParameter.Optional }
            );*/

            #endregion
        }

        public static void Register2<T>(HttpConfiguration config, T carrier) where T : DependencyResolves.BaseSettingsCarrier
        {
            var _DependencyResolver = new CommonWebAPI.DependencyResolves.BaseControllerDependencyResolver<T>(carrier);
            config.DependencyResolver = _DependencyResolver;
        }

    }
}
