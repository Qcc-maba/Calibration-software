
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Web;
using System.Web.Http;
using ViewModelLayer = Maba.Hydra2.Systems.MF.BL.ViewModelLayer;
using Maba.Hydra2.Systems.Common.CommonWebAPI.Controllers;
using CommonWebAPI = Maba.Hydra2.Systems.Common.CommonWebAPI;
using System.Net.Http;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.WebServices.Controllers
{
    [RoutePrefix("Device")]
    [Authorize]
    public class DeviceController : BaseController
    {
        #region Add Device Wizard

        [HttpGet]
        [Route("{SN}/Verify")]
        public async Task<CommonWebAPI.Models.Response<ViewModelLayer.Models.Device.SearchDeviceTypeModel>> VerifyDeviceSN(string SN)
        {
            return await this.HandleResponseTask<ViewModelLayer.Models.Device.SearchDeviceTypeModel>(async () =>
            {
                var authHeader = $"{this.Request.Headers.Authorization.Scheme} {this.Request.Headers.Authorization.Parameter}";

                var deviceManager = CreateMFManager<ViewModelLayer.Models.Device.DeviceModelViewManager>();
                var searchResult = await deviceManager.FindDeviceTypeAsync(this.CurrentUser.UserID, SN, authHeader);

                #region validate search 

                if (searchResult == null)
                {
                    throw this.ThrowHttpResponseException(new Common.CommonWebAPI.Models.MessageCodeModel[]
                    {
                    new Common.CommonWebAPI.Models.MessageCodeModel(10, "Couldn't find KnownType for this serial {0}",SN),
                    },
                    System.Net.HttpStatusCode.InternalServerError);
                }

                #endregion

                return new Common.CommonWebAPI.Models.Response<BL.ViewModelLayer.Models.Device.SearchDeviceTypeModel>()
                {
                    Body = searchResult
                };
            });
        }

        [HttpPost]
        [Route("Add")]
        public async Task<CommonWebAPI.Models.Response<ViewModelLayer.Models.Device.AddDeviceResponseModel>> AddNewDevice(ViewModelLayer.Models.Device.AddDeviceRequestModel AddRequest)
        {
            return await this.HandleResponseTask<ViewModelLayer.Models.Device.AddDeviceResponseModel>(async () =>
            {
                var deviceManager = CreateMFManager<ViewModelLayer.Models.Device.DeviceModelViewManager>();

                var authHeader = $"{this.Request.Headers.Authorization.Scheme} {this.Request.Headers.Authorization.Parameter}";

                var addResult = await deviceManager.AddDeviceAsync(this.CurrentUser.Email, this.CurrentUser.UserID, AddRequest, authHeader);
                return new Common.CommonWebAPI.Models.Response<BL.ViewModelLayer.Models.Device.AddDeviceResponseModel>()
                {
                    Result = addResult != null && addResult.Status,
                    Body = addResult
                };
            });
        }

        #endregion

        #region get device and update

        [HttpGet]
        [Route("{SN}")]
        public async Task<CommonWebAPI.Models.Response<ViewModelLayer.Models.Device.DeviceView>> GetDevice(string SN)
        {
            return await Task.Run(() =>
            {
                return this.HandleResponse<ViewModelLayer.Models.Device.DeviceView>(() =>
                {
                    var DeviceManager = CreateMFManager<ViewModelLayer.Models.Device.DeviceModelViewManager>();
                    return DeviceManager.GetDevice(this.CurrentUser.UserID, SN);
                });
            });

        }

        [HttpPost]
        [Route("{SN}")]
        public async Task<CommonWebAPI.Models.Response> UpdateDeviceName(string SN, string Name)
        {
            return await Task.Run(() =>
            {
                var DeviceManager = CreateMFManager<ViewModelLayer.Models.Device.DeviceModelViewManager>();
                return this.HandleResponse<bool>(() => DeviceManager.UpdateDeviceName(CurrentUser.UserID, SN, Name));
            });
        }

        [HttpGet]
        [Route("{SN}/Info")]
        public async Task<CommonWebAPI.Models.Response<ViewModelLayer.Models.Device.DeviceInfoView>> GetSiteInfo(string SN)
        {
            return await Task.Run(() =>
            {
                var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();
                return this.HandleResponse(() => SiteManager.GetDeviceInfo(CurrentUser.UserID, SN));
            });
        }

        [HttpGet]
        [Route("{SN}/Location")]
        public CommonWebAPI.Models.Response<ViewModelLayer.Models.MapPinLocationView> GetDeviceLocation(string SN)
        {
            return this.HandleResponse<ViewModelLayer.Models.MapPinLocationView>(
                       () =>
                       {
                           var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();

                           return SiteManager.GetDeviceLocaion(CurrentUser.UserID, SN);
                       });

        }

        [HttpPost]
        [Route("{SN}/Location")]
        public async Task<CommonWebAPI.Models.Response> UpdateDeviceLocation(string SN, ViewModelLayer.Models.MapPinLocationView Location)
        {
            return await this.HandleResponseTask(
                       async () =>
                       {
                           var SiteManager = CreateMFManager<ViewModelLayer.Models.Site.SiteModelViewManager>();
                           var authHeader = $"{this.Request.Headers.Authorization.Scheme} {this.Request.Headers.Authorization.Parameter}";

                           return new CommonWebAPI.Models.Response()
                           {
                               Result = await SiteManager.SaveDeviceMapLocationAsync(CurrentUser.UserID, SN, Location, authHeader)
                           };
                       });
        }

        [HttpGet]
        [Route("{SN}/Type")]
        public async Task<CommonWebAPI.Models.Response<ViewModelLayer.Models.Device.DeviceTypeView>> GetDeviceType(string SN)
        {
            return await Task.Run(() =>
            {
                var DeviceManager = CreateMFManager<ViewModelLayer.Models.Device.DeviceModelViewManager>();

                return new CommonWebAPI.Models.Response<ViewModelLayer.Models.Device.DeviceTypeView>
                {
                    Result = true,
                    Body = DeviceManager.GetDeviceType(this.CurrentUser.UserID, SN)
                };
            });
        }

        [HttpPost]
        [Route("{SN}/Link")]
        public async Task<CommonWebAPI.Models.Response> UnlinkDeviceFromSite(string SN, long? NewParentSiteID)
        {
            return await Task.Run(() =>
            {
                var DeviceManager = CreateMFManager<ViewModelLayer.Models.Device.DeviceModelViewManager>();
                return new CommonWebAPI.Models.Response()
                {
                    Result = DeviceManager.UnlinkDevice(this.CurrentUser.UserID, SN, NewParentSiteID)
                };
            });
        }

        #endregion

        #region AlertSettings

        [HttpGet]
        [Route("{SN}/AlertSettings")]
        public async Task<CommonWebAPI.Models.Response<ViewModelLayer.Models.Device.DeviceAlertSettingsView[]>> GetAlertSettings(string SN)
        {
            return await Task.Run(() =>
            {
                var DeviceManager = CreateMFManager<ViewModelLayer.Models.Device.DeviceModelViewManager>();
                return new CommonWebAPI.Models.Response<ViewModelLayer.Models.Device.DeviceAlertSettingsView[]>
                {
                    Result = true,
                    Body = DeviceManager.GetDeviceAlertSettings(this.CurrentUser.UserID, SN)
                };
            });
        }

        [HttpPost]
        [Route("{SN}/Alerts")]
        public async Task<CommonWebAPI.Models.Response> UpdateAlertSettings(string SN, CommonWebAPI.Models.Request<ViewModelLayer.Models.Device.DeviceAlertSettingsView[]> alertSettings)
        {
            return await Task.Run(() =>
            {
                var DeviceManager = CreateMFManager<ViewModelLayer.Models.Device.DeviceModelViewManager>();
                return new CommonWebAPI.Models.Response()
                {
                    Result = DeviceManager.UpdateDeviceAlertSettings(this.CurrentUser.UserID, SN, alertSettings.Body)
                };
            });
        }

        [HttpPost]
        [Route("{SN}/Alerts")]
        public async Task<CommonWebAPI.Models.Response> ChangeDeviceAlertsEnabled(string SN, bool AlertEnabled)
        {
            return await Task.Run(() =>
            {
                var DeviceManager = CreateMFManager<ViewModelLayer.Models.Device.DeviceModelViewManager>();
                return new CommonWebAPI.Models.Response()
                {
                    Result = DeviceManager.UpdateDevice_AlertsSettings(this.CurrentUser.UserID, SN, AlertEnabled)
                };
            });
        }

        #endregion
    }
}