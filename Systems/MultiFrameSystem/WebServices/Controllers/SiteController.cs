
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
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.WebServices.Controllers
{
    [RoutePrefix("Site")]
    [Authorize]
    public class SiteController : BaseController
    {
        #region Site

        [HttpPost]
        [Route("")]
        public CommonWebAPI.Models.Response<long> AddSite(string SiteName, long ParentProjectID)
        {
            var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();
            return this.HandleResponse(() => SiteManager.CreateSite(CurrentUser.UserID, SiteName, ParentProjectID, null));
        }

        [HttpGet]
        [Route("{SiteID}")]
        public CommonWebAPI.Models.Response<ViewModelLayer.Models.Site.SiteView> GetSite(long SiteID)
        {
            var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();
            return this.HandleResponse(() => SiteManager.GetSite(CurrentUser.UserID, SiteID));
        }

        [HttpDelete]
        [Route("{SiteID}")]
        public CommonWebAPI.Models.Response DeleteSite(long SiteID)
        {
            var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();
            return this.HandleResponse(() => SiteManager.DeleteSite(this.CurrentUser.UserID, SiteID));
        }

        [HttpGet]
        [Route("{SiteID}/Info")]
        public CommonWebAPI.Models.Response<ViewModelLayer.Models.Site.SiteInfoView> GetSiteInfo(long SiteID)
        {
            var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();
            return this.HandleResponse<ViewModelLayer.Models.Site.SiteInfoView>(() =>
             SiteManager.GetSiteInfoView(CurrentUser.UserID, SiteID));
        }

        [HttpGet]
        [Route("{SiteID}/Map")]
        public CommonWebAPI.Models.Response<ViewModelLayer.Models.Site.SiteMapContainerView> GetSiteMapContainer(long SiteID)
        {
            var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();
            return this.HandleResponse<ViewModelLayer.Models.Site.SiteMapContainerView>(() =>
            {
                var map = SiteManager.GetSiteMapContainer(CurrentUser.UserID, SiteID);
                return map;
            });
        }

        [HttpPost]
        [Route("{SiteID}/Location")]
        public CommonWebAPI.Models.Response<ViewModelLayer.Models.MapLocationView> UpdateSiteLocation(long SiteID, ViewModelLayer.Models.MapLocationView Location)
        {
            var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();
            return this.HandleResponse<ViewModelLayer.Models.MapLocationView>(
                        () => Location,
                        () => SiteManager.SaveSiteMapLocation(CurrentUser.UserID, SiteID, Location));
        }

        [HttpPost]
        [Route("{SiteID}")]
        public CommonWebAPI.Models.Response UpdateSite(long SiteID, string SiteName)
        {
            var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();
            return this.HandleResponse(() => SiteManager.UpdateSite(CurrentUser.UserID, SiteID, SiteName));
        }

        #endregion

        #region Site / Devices

        [HttpPost]
        [Route("{SiteID}/Map/{SN}")]
        public async Task<CommonWebAPI.Models.Response<ViewModelLayer.Models.MapPinLocationView>> UpdateDeviceLocation(long SiteID, string SN, ViewModelLayer.Models.MapPinLocationView Location)
        {
            //var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();

            //return this.HandleResponse<ViewModelLayer.Models.MapPinLocationView>(
            //           () => Location,
            //           () => SiteManager.SaveDeviceMapLocationAsync(CurrentUser.UserID, SN, Location));


            return await this.HandleResponseTask(
                       async () =>
                       {
                           var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();
                           var authHeader = $"{this.Request.Headers.Authorization.Scheme} {this.Request.Headers.Authorization.Parameter}";

                           var updateResult = await SiteManager.SaveDeviceMapLocationAsync(CurrentUser.UserID, SN, Location, authHeader);
                           return new CommonWebAPI.Models.Response<ViewModelLayer.Models.MapPinLocationView>()
                           {
                               Result = updateResult,
                               Body = Location
                           };
                       });
        }

        [HttpGet]
        [Route("{SiteID}/Devices")]
        public CommonWebAPI.Models.Response<ViewModelLayer.Models.Device.DeviceListView[]> GetSiteDevices(long SiteID)
        {
            var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();
            return this.HandleResponse<ViewModelLayer.Models.Device.DeviceListView[]>(() => SiteManager.GetSiteDevicesList(CurrentUser.UserID, SiteID));
        }

        #endregion

        /// FIXED UNTIL HERE ///////////////////////////////////////////////////////////////////////////////////////////////////////

        #region TBD SessionSetting
        /*
        [HttpGet]
        [Route("{SiteID}/SessionSetting")]
        public CommonWebAPI.Models.Response<ViewModelLayer.Models.Site.SessionSettingView[]> GetSiteSessionSetting(long SiteID)
        {
            var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();
            return this.HandleResponse<ViewModelLayer.Models.Site.SessionSettingView[]>(() =>
            SiteManager.GetSiteSessionSetting(CurrentUser.UserID, SiteID));
        }

        [HttpPost]
        [Route("{SiteID}/SessionSetting")]
        public CommonWebAPI.Models.Response UpdateSiteSessionSetting(long SiteID, ViewModelLayer.Models.Site.SessionSettingView[] SessionList)
        {
            var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();
            return this.HandleResponse(() =>
            SiteManager.UpdateSiteSessionSetting(CurrentUser.UserID, SiteID, SessionList));
        }
        

        [HttpGet]
        [Route("{SiteID}/SessionSetting/{SessionID}")]
        public CommonWebAPI.Models.Response<ViewModelLayer.Models.Site.SessionDaySettingViewRespons> GetSessionDaySetting(long SiteID,long SessionID)
        {
            var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();

            return this.HandleResponse<ViewModelLayer.Models.Site.SessionDaySettingViewRespons>(() =>
            SiteManager.GetSessionDaySetting(CurrentUser.UserID, SiteID , SessionID));
        }

        [HttpPost]
        [Route("{SiteID}/SessionSetting/{SessionID}")]
        public CommonWebAPI.Models.Response UpdateSiteSession(long SiteID, long SessionID, ViewModelLayer.Models.Site.SessionDaySettingView[] SessionDayList)
        {
            var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();
            return this.HandleResponse(() =>
            SiteManager.UpdateSiteSessionDay(CurrentUser.UserID, SiteID, SessionDayList, SessionID));
        }
        */
        #endregion

        #region Site Sharing process

        [HttpGet]
        [Route("{SiteID}/Users")]
        public CommonWebAPI.Models.Response<ViewModelLayer.Models.Site.SharedSiteSettingsView[]> SiteSharedUsers_GetAllUsers(long SiteID)
        {
            var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();
            return this.HandleResponse<ViewModelLayer.Models.Site.SharedSiteSettingsView[]>(() => SiteManager.SiteSharedUsers_GetAllUsers(this.CurrentUser.UserID, SiteID));
        }

        [HttpPost]
        [Route("{SiteID}/Users")]
        public CommonWebAPI.Models.Response<ViewModelLayer.Models.Site.SharedSiteSettingsView[]> SiteSharedUsers_Update(long SiteID, ViewModelLayer.Models.Site.SharedSiteSettingsView[] SharedSiteList)
        {
            var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();

            return this.HandleResponse<ViewModelLayer.Models.Site.SharedSiteSettingsView[]>(() =>
            {
                return SiteManager.SiteSharedUsers_Update(this.CurrentUser.UserID, this.CurrentUser.Email, SiteID, SharedSiteList);
            });
        }

        //[HttpDelete]
        //[Route("{SiteID}/Users")]
        //public CommonWebAPI.Models.Response SiteSharedUsers_DeleteUser(long SiteID, long LinkedUserID)
        //{
        //    var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();
        //    return this.HandleResponse(() => SiteManager.SiteSharedUsers_DeleteUser(this.CurrentUser.UserID, SiteID, LinkedUserID));
        //}

        #endregion

        #region Transfer process

        /// <summary>
        /// Start Transfer
        /// </summary>
        /// <param name="SiteID">SourceSiteID</param>
        /// <param name="Email">TargetUserEmail</param>
        /// <returns></returns>
        //[HttpPost]
        //[Route("{SiteID}/Transfer")]
        //public CommonWebAPI.Models.Response<ViewModelLayer.Models.Site.TransferSiteView> TransferSite_Start(long SiteID, string Email)
        //{
        //    var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();
        //    return this.HandleResponse(() => SiteManager.TransferSite_Start(this.CurrentUser.UserID, Email, this.CurrentUser.Email, SiteID));
        //}

        [HttpGet]
        [Route("{SiteID}/Transfer")]
        public CommonWebAPI.Models.Response<ViewModelLayer.Models.Site.TransferSiteView> TransferSite_GetAllPending(long SiteID)
        {
            var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();
            return this.HandleResponse(() => SiteManager.TransferSite_GetAllPendings(this.CurrentUser.UserID, SiteID));
        }

        [HttpDelete]
        [Route("{SiteID}/Transfer")]
        public CommonWebAPI.Models.Response TransferSite(long SiteID)
        {
            var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();
            return this.HandleResponse(() => SiteManager.TransferSite_Cancel(this.CurrentUser.UserID, SiteID));
        }

        [HttpPost]
        [Route("{SiteID}/LocalTransfer")]
        public CommonWebAPI.Models.Response LocalTransfer(long SiteID, long ProjectID)
        {
            var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();
            return this.HandleResponse(() => SiteManager.TransferSite_LocalTransfer(this.CurrentUser.UserID, SiteID, ProjectID));
        }
        #endregion
    }
}
