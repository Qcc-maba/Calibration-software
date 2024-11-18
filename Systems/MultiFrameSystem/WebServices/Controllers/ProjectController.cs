using Microsoft.Owin.Security;
using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Security.Claims;
using System.Web.Http;
using ViewModelLayer = Maba.Hydra2.Systems.MF.BL.ViewModelLayer;
using Maba.Hydra2.Systems.Common.CommonWebAPI.Controllers;
using CommonWebAPI = Maba.Hydra2.Systems.Common.CommonWebAPI;
using Microsoft.AspNet.Identity.Owin;
using Microsoft.AspNet.Identity;
using System.Threading.Tasks;
using Maba.AccountSystem.AspNetIdentity.Identity2.Common;

namespace Maba.Hydra2.Systems.MF.WebServices.Controllers
{
    [RoutePrefix("Project")]
    [Authorize]
    public class ProjectController : BaseController
    {
        [HttpGet]
        [Route("Exchange")]
        [AllowAnonymous]
        public async Task<CommonWebAPI.Models.Response<Models.ExchangeResultModel>> GetExchange()
        {
            return await this.HandleResponseTask(async () =>
            {
                //validate we have account identity
                var accountIdentity = GetIdentity(InheritedTest: false);
                var userIDClaim = accountIdentity.Claims.FirstOrDefault(C => C.Type == ClaimTypes.Sid);
                long CurrentUserID = long.Parse(userIDClaim.Value);

                //get current user profile from account system
                var authHeader = this.Request.Headers.Authorization;

                var userProfile = await Models.ApplicationUserModel.GetUserProfile(this.Carrier.Properties.AccountSystemURI, authHeader);

                if (userProfile == null
                        || userProfile.Body == null
                        || !userProfile.Result
                        || String.IsNullOrEmpty(userProfile.Body.Email))
                {
                    throw this.ThrowHttpResponseException(new Common.CommonWebAPI.Models.MessageCodeModel[]
                     {
                        new Common.CommonWebAPI.Models.MessageCodeModel(0, "Couldn't get this user from Identity system")
                     },
                     HttpStatusCode.Forbidden);
                }

                //check if user exists in this system
                var ProjectManager = CreateMFManager<ViewModelLayer.Models.Project.ProjectViewModelManager>();
                var exhangeUser = new ViewModelLayer.Models.User.UserView()
                {
                    CultureCode = userProfile.Body.CultureCode,
                    Email = userProfile.Body.Email,
                    FirstName = userProfile.Body.FirstName,
                    LastName = userProfile.Body.LastName,
                    ImgURL = userProfile.Body.ImgURL,
                    TimeZoneID = userProfile.Body.TimeZoneID,
                    AccountUserGUID = userProfile.Body.UserGuid
                };

                var authHeaderParts = authHeader.Parameter.Split(new char[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
                var exchangeResult = ProjectManager.MakeFirstExchangeProcess(exhangeUser, authHeaderParts[authHeaderParts.Length - 1].Substring(0, 20));

                //---------------------------------- VERY IMPORTANT PART ----------------------------------
                //add this online system token identifier
                if (!accountIdentity.Claims.Any(c => c.Type == BaseController.MF_CLAIM))
                {
                    accountIdentity.AddClaim(new Claim(BaseController.MF_CLAIM, ""));
                }

                //change UserID
                accountIdentity.SetUserId(exchangeResult.Get_UserID());
                accountIdentity.SetUserTemperatureUnit(userProfile.Body.Temperature_UnitView);
                accountIdentity.SetUserCultureCode(userProfile.Body.CultureCode);


                var tokenHelper = AccountSystem.AspNetIdentity.Identity2.Common.AccessTokenHelper.CreateAccessTokenHelper(
                                                                                                    this.Carrier.DataProtectionOptions.CreateDataProtectionProvider(),
                                                                                                    this.Carrier.DataProtectionOptions.Purposes);
                var ticket = AccountSystem.AspNetIdentity.Identity2.Common.AccessTokenHelper.CreateUserTicket(accountIdentity);
                var newTicket = tokenHelper.Protect(ticket);

                return new CommonWebAPI.Models.Response<Models.ExchangeResultModel>()
                {

                    Body = new Models.ExchangeResultModel()
                    {
                        ExchangeData = exchangeResult,
                        UserModel = userProfile.Body,
                        NewToken = newTicket
                    }
                };
            });
        }

        #region Tree and Project lists

        [HttpGet]
        [Route("Tree")]
        public CommonWebAPI.Models.Response<ViewModelLayer.Models.Project.ProjectsTreeViewModel> ProjectsTree(int PageNumber, string Search = null, int PageSize = 10)
        {
            return this.HandleResponse(() =>
            {
                var ProjectManager = CreateMFManager<ViewModelLayer.Models.Project.ProjectViewModelManager>();
                var userManager = CreateMFManager<ViewModelLayer.Models.User.UserViewModelManager>();
                var tree = ProjectManager.GetProjectsTree(this.CurrentUser.UserID, PageNumber, PageSize, Search);

                return tree;
            });
        }

        [HttpGet]
        [Route("Tree/{ProjectID}")]
        public CommonWebAPI.Models.Response<ViewModelLayer.Models.Project.ProjectsTreeViewModel> GetProjectTree(long ProjectID, int PageSize = 10)
        {
            return this.HandleResponse(() =>
            {
                var ProjectManager = CreateMFManager<ViewModelLayer.Models.Project.ProjectViewModelManager>();
                var userManager = CreateMFManager<ViewModelLayer.Models.User.UserViewModelManager>();
                var tree = ProjectManager.GetProjectsTree(this.CurrentUser.UserID, ProjectID, PageSize);

                return tree;
            });
        }

        [HttpGet]
        [Route("Projects")]
        public CommonWebAPI.Models.Response<ViewModelLayer.Models.Project.ProjectListView[]> GetProjects()
        {
            return this.HandleResponse(() =>
            {
                var ProjectManager = CreateMFManager<ViewModelLayer.Models.Project.ProjectViewModelManager>();

                var projects = ProjectManager.GetProjects(this.CurrentUser.UserID);

                return projects;
            });
        }

        #endregion

        #region Project CRUD

        [HttpDelete]
        [Route("{ProjectID}")]
        public CommonWebAPI.Models.Response DeleteProject(long ProjectID)
        {
            return this.HandleResponse(() =>
            {
                var ProjectManager = CreateMFManager<ViewModelLayer.Models.Project.ProjectViewModelManager>();

                return ProjectManager.DeleteProject(this.CurrentUser.UserID, ProjectID);
            });
        }

        [HttpGet]
        [Route("{ProjectID}")]
        public CommonWebAPI.Models.Response<ViewModelLayer.Models.Project.ProjectView> GetProject(long ProjectID)
        {
            return this.HandleResponse(() =>
            {
                var ProjectManager = CreateMFManager<ViewModelLayer.Models.Project.ProjectViewModelManager>();

                return ProjectManager.GetProject(this.CurrentUser.UserID, ProjectID);
            });
        }

        [HttpPost]
        [Route("")]
        public CommonWebAPI.Models.Response<ViewModelLayer.Models.Project.ProjectView> AddProject(string ProjectName, ViewModelLayer.Models.MapLocationView Location)
        {
            return this.HandleResponse(() =>
            {
                var ProjectManager = CreateMFManager<ViewModelLayer.Models.Project.ProjectViewModelManager>();

                var newProjectID = ProjectManager.CreateProject(this.CurrentUser.UserID, ProjectName, Location);

                var newProject = ProjectManager.GetProject(this.CurrentUser.UserID, newProjectID);

                return newProject;
            });
        }

        [HttpPost]
        [Route("{ProjectID}")]
        public CommonWebAPI.Models.Response<bool> UpdateProject(long ProjectID, string ProjectName)
        {
            return this.HandleResponse(() =>
            {
                var ProjectManager = CreateMFManager<ViewModelLayer.Models.Project.ProjectViewModelManager>();

                var result = ProjectManager.UpdateProject(this.CurrentUser.UserID, ProjectID, ProjectName);
                return result;
            });
        }

        #endregion

        #region project Alerts

        [HttpGet]
        [Route("{ProjectID}/Alerts")]
        public CommonWebAPI.Models.Response<ViewModelLayer.Models.Project.ProjectAlertsView> GetProjectsAlerts(long ProjectID, bool IncludedSub = true, int PageNumber = 1, int PageSize = 10)
        {
            return this.HandleResponse(() =>
            {
                var ProjectManager = CreateMFManager<ViewModelLayer.Models.Project.ProjectViewModelManager>();

                return ProjectManager.GetProjectsAlerts(this.CurrentUser.UserID, ProjectID, IncludedSub, PageNumber, PageSize);
            });
        }

        [HttpPost]
        [Route("{ProjectID}/Alerts")]
        public CommonWebAPI.Models.Response UpdateProjectsAlerts(long ProjectID, ViewModelLayer.Models.Project.UpdateProjectAlertsModel ProjectAlertView)
        {
            return this.HandleResponse(() =>
            {
                var ProjectManager = CreateMFManager<ViewModelLayer.Models.Project.ProjectViewModelManager>();
                return ProjectManager.UpdateProjectAlerts(this.CurrentUser.UserID, ProjectAlertView);
            });
        }

        [HttpPost]
        [Route("{ProjectID}/MacroAlerts")]
        public CommonWebAPI.Models.Response UpdateMacroAlerts(long ProjectID, bool Status, bool IncludedSub = true)
        {
            return this.HandleResponse(() =>
            {
                var ProjectManager = CreateMFManager<ViewModelLayer.Models.Project.ProjectViewModelManager>();
                return ProjectManager.UpdateMacroAlerts(this.CurrentUser.UserID, ProjectID, Status, IncludedSub);
            });
        }

        #endregion
    }
}

