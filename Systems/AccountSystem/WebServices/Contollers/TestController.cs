using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using System.Web.Http;

namespace Maba.AccountSystem.WebServices.Contollers
{
    [RoutePrefix("Test")]
    [AllowAnonymous]
    public class TestController : BaseController
    {
        [Route("Server")]
        [HttpGet]
        public HttpResponseMessage HelloServer()
        {
            var principal = this.RequestContext.Principal;
            var identity = this.User.Identity as System.Security.Claims.ClaimsIdentity;

            var jToken = new JObject();
            jToken.Add(new JProperty("MachineName", Environment.MachineName));

            #region OS

            var os_Token = new JObject();
            os_Token.Add(new JProperty("Platform", Environment.OSVersion.Platform.ToString()));
            os_Token.Add(new JProperty("ServicePack", Environment.OSVersion.VersionString));
            os_Token.Add(new JProperty("Version", Environment.OSVersion.Version.ToString()));
            jToken.Add("OS", os_Token);

            #endregion

            jToken.Add(new JProperty("ProcessorCount", Environment.ProcessorCount));
            jToken.Add(new JProperty("Version", Environment.Version.ToString()));
            jToken.Add(new JProperty("UserName", Environment.UserName));
            jToken.Add(new JProperty("Is64BitProcess", Environment.Is64BitProcess));
            jToken.Add(new JProperty("Is64BitOperatingSystem", Environment.Is64BitOperatingSystem));

            #region current HostName / IP address

            var localAddressToken = new JObject();
            var localAddress = System.Net.Dns.GetHostEntry("");
            localAddressToken.Add(new JProperty("HostName", localAddress.HostName));
            if (localAddress.Aliases != null && localAddress.Aliases.Length > 0)
            {
                localAddressToken.Add(new JProperty("HostName", string.Concat(localAddress.Aliases.Select(s => s + ","))));
            }

            //locla address
            var localAddress_array = new JArray();
            foreach (var addr in localAddress.AddressList)
            {
                localAddress_array.Add(addr.ToString());
            }
            localAddressToken.Add("AddressList", localAddress_array);
            jToken.Add("DNSEntry", localAddressToken);
            #endregion

            var resp = new HttpResponseMessage();
            resp.Content = new StringContent(jToken.ToString(Newtonsoft.Json.Formatting.Indented), Encoding.UTF8, "text/plain");
            return resp;
        }

        [Route("Ver")]
        [OWIN.Security.Attributes.HostFilterAuthorize(OnlyLoopback = true)]
        [HttpGet]
        public HttpResponseMessage AssembliesVersion(string filter = "")
        {
            var jToken = new JObject();

            //root
            var assembliesToken = new JObject();

            //get all assemblies
            var assemblies = AppDomain.CurrentDomain.GetAssemblies();
            var totalAsseblies = assemblies.Length;
            assembliesToken.Add("Total", totalAsseblies.ToString());

            int filteredtotalAsseblies = 0;

            if (!String.IsNullOrEmpty(filter))
            {
                assemblies = assemblies
                    .Where(a => a.FullName.Contains(filter))
                    .ToArray();

                filteredtotalAsseblies = assemblies.Length;

                assembliesToken.Add("TotalFiltered", filteredtotalAsseblies.ToString());
            }

            //build assemblies list
            var assemblies_ArrayToken = new JArray();
            for (int i = 0; i < assemblies.Length; i++)
            {
                var a = assemblies[i];
                var assemblyToken = new JObject();
                assemblyToken.Add("Name", a.GetName().Name);
                assemblyToken.Add("FullName", a.FullName);
                assemblyToken.Add("Version", a.GetName().Version.ToString());
                assemblyToken.Add("TotalDefinedTypes", a.DefinedTypes.Count().ToString());

                if (filteredtotalAsseblies == 1)
                {
                    var assembly_definedTypes_JArray = new JArray();
                    foreach (var t in a.DefinedTypes)
                    {
                        assembly_definedTypes_JArray.Add(t.Name);
                    }
                    assemblyToken.Add("DefinedTypes", assembly_definedTypes_JArray);
                }

                try
                {
                    var assemblyfile_Token = new JObject();

                    var file = new FileInfo(a.Location);
                    assemblyfile_Token.Add("Name", file.Name);
                    assemblyfile_Token.Add("Length", file.Length);
                    assemblyfile_Token.Add("LastWriteTimeUtc", file.LastWriteTimeUtc);

                    assemblyToken.Add("File", assemblyfile_Token);
                }
                catch { }

                assemblies_ArrayToken.Add(assemblyToken);
            }

            assembliesToken.Add("list", assemblies_ArrayToken);
            jToken.Add("Assemblies", assembliesToken);

            var resp = new HttpResponseMessage();
            resp.Content = new StringContent(jToken.ToString(Newtonsoft.Json.Formatting.Indented), Encoding.UTF8, "text/plain");
            return resp;
        }

        [Route("Providers/DB")]
        [OWIN.Security.Attributes.HostFilterAuthorize(OnlyLoopback = true)]
        [HttpGet]
        public async Task<HttpResponseMessage> ValidateDBConnection()
        {
            var jToken = new JObject();

            bool success = false;
            try
            {
                var rolesResult = await this.UserManager.System_RoleModels();
                success = rolesResult.Succeeded && rolesResult.Result != null;
            }
            catch (System.Exception e)
            {
                var exceptionToken = new JObject();
                exceptionToken.Add("Type", e.GetType().Name);
                exceptionToken.Add("Message", e.Message);

                jToken.Add("Exception", exceptionToken);
            }

            jToken.Add("Result", success);


            var resp = new HttpResponseMessage();
            resp.Content = new StringContent(jToken.ToString(Newtonsoft.Json.Formatting.Indented), Encoding.UTF8, "text/plain");
            return resp;
        }
    }
}
