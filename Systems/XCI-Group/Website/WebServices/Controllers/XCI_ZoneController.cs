using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;
using CommonWebAPI = Maba.Hydra2.Systems.Common.CommonWebAPI;
using System.Threading.Tasks;
using System.IO;
using Maba.Hydra2.Systems.Common.CommonWebAPI.Controllers;
using Maba.Hydra2.Systems.Common.CommonWebAPI.Models;

namespace Maba.Hydra2.Systems.XCIGroup.WebServices.Controllers
{
    [RoutePrefix("Zone")]
    public class XCI_ZoneController : BaseController
    {
        private const string MIME_IMGAE_PREFIX = "image/";

        #region CategoriesAdvisor

        [HttpGet]
        [Route("{SN}/{ZoneNumber}/ScheduleAdvisor")]
        public CommonWebAPI.Models.Response<BL.ViewModelLayer.Models.Zone.AdvisorAllOptionsView> GetScheduleAdvisor(string SN, int ZoneNumber)
        {
            ViewOnlySN(SN);
            var ZoneManager = CreateXCIManager<BL.ViewModelLayer.Models.Zone.ZoneModelManager>();
            return this.HandleResponse<BL.ViewModelLayer.Models.Zone.AdvisorAllOptionsView>(() => ZoneManager.GetScheduleAdvisor(SN, ZoneNumber));
        }

        [HttpGet]
        [Route("{SN}/{ZoneNumber}/IrrigationSuggestion")]
        public CommonWebAPI.Models.Response<BL.ViewModelLayer.Models.Zone.ZoneIrrigationSuggestionView> GetIrrigationSuggestion(string SN, int ZoneNumber)
        {
            ViewOnlySN(SN);
            var ZoneManager = CreateXCIManager<BL.ViewModelLayer.Models.Zone.ZoneModelManager>();
            return this.HandleResponse<BL.ViewModelLayer.Models.Zone.ZoneIrrigationSuggestionView>(() => ZoneManager.GetIrrigationSuggestion(SN, ZoneNumber));
        }

        [HttpPost]
        [Route("{SN}/{ZoneNumber}/ScheduleAdvisor")]
        public CommonWebAPI.Models.Response<BL.ViewModelLayer.Models.Zone.ZoneIrrigationSuggestionView> UpdateScheduleAdvisor(string SN, int ZoneNumber, BL.ViewModelLayer.Models.Zone.AdvisorUpdateSelectedTypeView[] Request)
        {
            RoleModifySN(SN);
            var ZoneManager = CreateXCIManager<BL.ViewModelLayer.Models.Zone.ZoneModelManager>();
            return this.HandleResponse<BL.ViewModelLayer.Models.Zone.ZoneIrrigationSuggestionView>(() => ZoneManager.UpdateScheduleAdvisor(SN, ZoneNumber, Request));
        }


        [HttpPost]
        [Route("{SN}/{ZoneNumber}/AcceptSuggestion")]
        public CommonWebAPI.Models.Response Zone_AcceptSuggestion(string SN, int ZoneNumber)
        {
            RoleModifySN(SN);
            var ZoneManager = CreateXCIManager<BL.ViewModelLayer.Models.Zone.ZoneModelManager>();
            return this.HandleResponse(() => ZoneManager.AcceptSuggestion(SN, ZoneNumber));

        }

        #endregion

        #region Zone

        [HttpGet]
        [Route("{SN}/{ZoneNumber}/ZoneInfo")]
        public CommonWebAPI.Models.Response<BL.ViewModelLayer.Models.Zone.ZoneListView> GetZoneInfo(string SN, int ZoneNumber)
        {
            ViewOnlySN(SN);
            var ZoneManager = CreateXCIManager<BL.ViewModelLayer.Models.Zone.ZoneModelManager>();
            return this.HandleResponse<BL.ViewModelLayer.Models.Zone.ZoneListView>(() => ZoneManager.GetZoneInfo(SN, ZoneNumber));
        }

        [HttpGet]
        [Route("{SN}/{ZoneNumber}")]
        public CommonWebAPI.Models.Response<BL.ViewModelLayer.Models.Zone.ZoneView> GetZone(string SN, int ZoneNumber)
        {
            return this.HandleResponse(() =>
            {
                ViewOnlySN(SN);
                var ZoneManager = CreateXCIManager<BL.ViewModelLayer.Models.Zone.ZoneModelManager>();
                return ZoneManager.GetZone(SN, ZoneNumber);
            });
        }

        [HttpPost]
        [Route("{SN}/{ZoneNumber}")]
        public CommonWebAPI.Models.Response SetZone(string SN, int ZoneNumber, string Name)
        {
            RoleModifySN(SN);
            var ZoneManager = CreateXCIManager<BL.ViewModelLayer.Models.Zone.ZoneModelManager>();
            var z = ZoneManager.GetZone(SN, ZoneNumber);
            return this.HandleResponse(() => ZoneManager.UpdateZone(SN, ZoneNumber, Name));
        }

        #endregion

        #region Zone settings

        #region specific change (from zone list)


        #endregion


        #region Schedule

        [HttpPost]
        [Route("{SN}/{ZoneNumber}/Schedule/Odd")]
        public CommonWebAPI.Models.Response Zone_UpdateOddSchedule(string SN, int ZoneNumber, BL.ViewModelLayer.Models.Zone.Schedule.ZoneIrrigationScheduleDailyView Request)
        {
            RoleModifySN(SN);
            var ZoneManager = CreateXCIManager<BL.ViewModelLayer.Models.Zone.ZoneModelManager>();
            return this.HandleResponse(() => ZoneManager.UpdateSchedule_OddEven_Zone(SN, ZoneNumber, Request, BL.ViewModelLayer.Models.Device.Schedule.BaseDeviceScheduleView.ScheduleTypes.Odd));
        }

        [HttpPost]
        [Route("{SN}/{ZoneNumber}/Schedule/Even")]
        public CommonWebAPI.Models.Response Zone_UpdateEvenSchedule(string SN, int ZoneNumber, BL.ViewModelLayer.Models.Zone.Schedule.ZoneIrrigationScheduleDailyView Request)
        {
            RoleModifySN(SN);
            var ZoneManager = CreateXCIManager<BL.ViewModelLayer.Models.Zone.ZoneModelManager>();
            return this.HandleResponse(() => ZoneManager.UpdateSchedule_OddEven_Zone(SN, ZoneNumber, Request, BL.ViewModelLayer.Models.Device.Schedule.BaseDeviceScheduleView.ScheduleTypes.Even));
        }

        [HttpPost]
        [Route("{SN}/{ZoneNumber}/Schedule/Weekly")]
        public CommonWebAPI.Models.Response Zone_UpdateWeeklySchedule(string SN, int ZoneNumber, BL.ViewModelLayer.Models.Zone.Schedule.ZoneIrrigationScheduleView Request)
        {
            RoleModifySN(SN);
            var ZoneManager = CreateXCIManager<BL.ViewModelLayer.Models.Zone.ZoneModelManager>();
            return this.HandleResponse(() => ZoneManager.UpdateSchedule_Weekly_Zone(SN, ZoneNumber, Request));
        }


        [HttpGet]
        [Route("{SN}/{ZoneNumber}/Schedule")]
        public CommonWebAPI.Models.Response<BL.ViewModelLayer.Models.Zone.Schedule.BaseZoneScheduleView> Zone_GetSchedule(string SN, int ZoneNumber, byte? SType = null)
        {
            RoleModifySN(SN);
            var ZoneManager = CreateXCIManager<BL.ViewModelLayer.Models.Zone.ZoneModelManager>();
            var response = this.HandleResponse<BL.ViewModelLayer.Models.Zone.Schedule.BaseZoneScheduleView>(() =>
                                                               ZoneManager.GetIrrigationSchedule(SN, ZoneNumber, (byte?)SType));

            return response;
        }

        #endregion

        #region Settings

        [HttpPost]
        [Route("{SN}/{ZoneNumber}/Settings")]
        public CommonWebAPI.Models.Response Zone_UpdateSettings(string SN, int ZoneNumber, BL.ViewModelLayer.Models.Zone.ZoneIrrigationSettingsView Request)
        {
            RoleModifySN(SN);
            var ZoneManager = CreateXCIManager<BL.ViewModelLayer.Models.Zone.ZoneModelManager>();
            return this.HandleResponse(() => ZoneManager.Zone_UpdateSettings(SN, ZoneNumber, Request));
        }

        [HttpPost]
        [Route("{SN}/{ZoneNumber}/FlowSensorSettings")]
        public CommonWebAPI.Models.Response Zone_UpdateFlowSensorSettings(string SN, int ZoneNumber, BL.ViewModelLayer.Models.Zone.ZoneFlowSensorSettingsView Request)
        {
            RoleModifySN(SN);
            var ZoneManager = CreateXCIManager<BL.ViewModelLayer.Models.Zone.ZoneModelManager>();
            return this.HandleResponse(() => ZoneManager.Zone_UpdateFlowSensorSettings(SN, ZoneNumber, Request));
        }

        /* [HttpPost]
         [Route("{SN}/{ZoneNumber}/Categories")]
         public CommonWebAPI.Models.Response Zone_UpdateCategories(string SN, int ZoneNumber, BL.ViewModelLayer.Models.Zone.ZoneCategoriesView Request)
         {
             RoleModifySN(SN);
             var ZoneManager = CreateXCIManager<BL.ViewModelLayer.Models.Zone.ZoneModelManager>();
             return this.HandleResponse(() => ZoneManager.Zone_UpdateCategories(SN, ZoneNumber, Request));
         }*/

        [HttpPost]
        [Route("{SN}/{ZoneNumber}/ImageUpload")]
        public async Task<CommonWebAPI.Models.Response<string>> Zone_ImageUpload(string SN, int ZoneNumber)
        {
            return await this.HandleResponseTask<string>(async () =>
            {
                //get current zone
                var ZoneManager = CreateXCIManager<BL.ViewModelLayer.Models.Zone.ZoneModelManager>();
                var zone = ZoneManager.GetZone(SN, ZoneNumber);
                
                var provider = await Request.Content.ReadAsMultipartAsync<MultipartMemoryStreamProvider>(new MultipartMemoryStreamProvider());
                foreach (HttpContent content in provider.Contents)
                {
                    Stream stream = content.ReadAsStreamAsync().Result;

                    string fileExtension = null, contentType = null;

                    #region get extension and Content-Type

                    //first try - take content-type and extension from header
                    if (content.Headers.ContentType != null && !String.IsNullOrEmpty(content.Headers.ContentType.MediaType))
                    {
                        contentType = content.Headers.ContentType.MediaType.ToLower();

                        if (contentType.StartsWith(MIME_IMGAE_PREFIX))
                        {
                            fileExtension = $".{contentType.Substring(MIME_IMGAE_PREFIX.Length)}";
                        }
                    }

                    //second try - take content-type and extension from filename extension
                    if (String.IsNullOrEmpty(contentType))
                    {
                        if (!String.IsNullOrEmpty(content.Headers.ContentDisposition.FileName))
                        {
                            fileExtension = Path.GetExtension(content.Headers.ContentDisposition.FileName.Replace("\"", ""));

                            contentType = $"{MIME_IMGAE_PREFIX}{fileExtension.Substring(1)}";
                        }
                    }

                    //last - fail this request if still none
                    if (String.IsNullOrEmpty(contentType))
                    {
                        throw this.ThrowHttpResponseException(new MessageCodeModel[]
                                                                                    {
                                                                                    new MessageCodeModel("No Content-Type found in request")
                                                                                    });
                    }

                    #endregion

                    var filename = $"Zone_{ZoneNumber}{SN}-{Guid.NewGuid().ToString().Substring(0, 4)}{fileExtension}";

                    using (var storageService = this.Carrier.ViewModelLayerSettings.ZonesFileSettings.GetStorageService())
                    {
                        #region upload to storage service

                        var uploadRequest = new Connectors.StorageLibrary.UploadRequest()
                        {
                            ContentType = contentType,
                            TargetPath = filename,
                            ACL = Connectors.StorageLibrary.ACLControl.Private
                        };
                        var response = await storageService.UploadFileStreamAsync(stream, uploadRequest);

                        #endregion

                        if (response.Result)
                        {
                            string uri;
                            if (String.IsNullOrEmpty(this.Carrier.ViewModelLayerSettings.ZonesFileSettings.Zones_CustomerImagesUrl))
                            {
                                uri = response.ObjectFullUrl;
                            }
                            else
                            {
                                uri = $"{this.Carrier.ViewModelLayerSettings.ZonesFileSettings.Zones_CustomerImagesUrl}/{filename}";
                            }

                            //finally update zone records
                            var Result = ZoneManager.Zone_UpdateImage(SN, ZoneNumber, filename);
                            if (Result)
                            {
                                //delete old image, if any
                                if (!String.IsNullOrEmpty(zone.ImageURI))
                                {
                                    try
                                    {
                                        await storageService.DeleteFileAsync(zone.ImageURI);
                                    }
                                    catch { }
                                }

                                return new Response<string>(uri);
                            }
                        }
                    }
                }

                return new Response<string>()
                {
                    Result = false
                };
            });
        }

        #endregion

        #endregion

    }
}