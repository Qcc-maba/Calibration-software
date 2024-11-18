using System;
using System.Threading.Tasks;
using Microsoft.Owin;
using Owin;
using System.Web.Http;
using Newtonsoft.Json.Serialization;

[assembly: OwinStartup(typeof(GatewayUI.Startup))]

namespace GatewayUI
{
    public class Startup
    {
        public void Configuration(IAppBuilder app)
        {
            //Newtonsoft.Json.JsonConvert.DeserializeObject
            HttpConfiguration config = new HttpConfiguration();
            config.MapHttpAttributeRoutes();
            
            //formatters
            var jsonFormmater = config.Formatters.JsonFormatter;
            config.Formatters.Clear();
            config.Formatters.Add(jsonFormmater);
            jsonFormmater.SerializerSettings.Formatting = Newtonsoft.Json.Formatting.Indented;
            config.Formatters.JsonFormatter.SerializerSettings.ContractResolver = new CamelCasePropertyNamesContractResolver();

            app.UseErrorPage();
            app.UseWelcomePage("/Welcome");
            app.UseWebApi(config);
        }
    }
}
