using System;
using System.Web.Http;
using ViewModelLayer = Maba.Hydra2.Systems.MF.BL.ViewModelLayer;
using Maba.Hydra2.Systems.Common.CommonWebAPI.Controllers;

namespace Maba.Hydra2.Systems.MF.WebServices.Controllers
{
    [RoutePrefix("Account")]
    [Authorize]
    public class AccountController : BaseController
    {
        [HttpGet]
        [Route("GetMessages")]
        public Common.CommonWebAPI.Models.Response<ViewModelLayer.Models.User.Messages.InboxMessagesView> GetMessages(
            int PageNumber = 1, int PageSize = 100)
        {
            var UserManager = CreateMFManager<ViewModelLayer.Models.User.UserViewModelManager>();

            return this.HandleResponse(() => UserManager.GetMessages(
                                                this.CurrentUser.Email, PageSize, PageNumber));
        }

        [HttpGet]
        [Route("CountMessages")]
        public Common.CommonWebAPI.Models.Response<int> CountMessages()
        {
            var UserManager = CreateMFManager<ViewModelLayer.Models.User.UserViewModelManager>();
            return this.HandleResponse(() => UserManager.CountMessages(this.CurrentUser.Email));
        }

        [HttpGet]
        [Route("Message")]
        public Common.CommonWebAPI.Models.Response<ViewModelLayer.Models.User.Messages.InboxMessageRecordView> GetMessage(string MessageID)
        {
            var UserManager = CreateMFManager<ViewModelLayer.Models.User.UserViewModelManager>();

            return this.HandleResponse(() => UserManager.GetMessage(this.CurrentUser.Email, MessageID));
        }

        [HttpPost]
        [Route("Message/Foldering/{MessageID}")]
        public Common.CommonWebAPI.Models.Response UpdateMessage_Foldering(string MessageID, bool Accepted, long? ProjectID = null, string ProjectName = null)
        {
            var siteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();

            return new Common.CommonWebAPI.Models.Response()
            {
                Result = siteManager.FolderinHydra2te_Accept(this.CurrentUser.Email, MessageID, Accepted, ProjectID, ProjectName)
            };
        }
    }
}
