using System;
using System.Linq;
using System.Net.Http;
using System.Web.Http;
using Microsoft.AspNet.Identity.Owin;
using Microsoft.AspNet.Identity;
using Microsoft.Owin.Security.DataHandler;
using OWINLibrary = Maba.Connectors.OWINLibrary;
using Identity2 = Maba.AccountSystem.AspNetIdentity.Identity2;
using CommonWebAPI = Maba.Hydra2.Systems.Common.CommonWebAPI;
using System.Security.Claims;
using Maba.AccountSystem.AspNetIdentity.Identity2.Common;
using System.Threading.Tasks;
using Newtonsoft.Json.Linq;
using System.Text;
using System.IO;
using System.Net.Http.Formatting;
using System.Net;

namespace Maba.AccountSystem.WebServices.Contollers
{
    public abstract class BaseController : CommonWebAPI.Controllers.BaseController<Settings.WebServicesSettings>
    {
        #region properties

        private Identity2.BL.Identity2UserManager _userManager;
        public Identity2.BL.Identity2UserManager UserManager
        {
            get
            {
                if (_userManager == null)
                {
                    _userManager = this.Carrier.Generator_UserManager();
                }
                return _userManager;
            }
        }

        #endregion

        public Exception ThrowHttpResponseWithResultException(CommonWebAPI.Models.MessageCodeModel[] messages = null, Identity2.ActionResult result = null, HttpStatusCode code = HttpStatusCode.BadRequest)
        {
            var response = new CommonWebAPI.Models.Response()
            {
                Messages = messages,
                Result = false
            };

            if (result != null)
            {
                response.Messages = (response.Messages ?? new CommonWebAPI.Models.MessageCodeModel[0])
                                                .Concat(result.Errors.Select(r => new CommonWebAPI.Models.MessageCodeModel(r)))
                                                .ToArray();
            }

            var jsonFormatter = this.RequestContext.Configuration.Formatters.JsonFormatter;

            return new HttpResponseException(new HttpResponseMessage(code)
            {
                Content = new ObjectContent<CommonWebAPI.Models.Response>(response, jsonFormatter)
            });
        }

    }
}