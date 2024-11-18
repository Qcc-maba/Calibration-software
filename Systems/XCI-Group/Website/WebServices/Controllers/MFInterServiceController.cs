using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace Maba.Hydra2.Systems.XCIGroup.WebServices.Controllers
{
    [RoutePrefix("Inter")]

    public class MFInterServiceController : BaseController
    {
        [Route("{SN}/Verify")]
        [HttpGet]
        public Common.CommonWebAPI.Models.Response<VerifySNResponseModel> VerifyDevice(string SN)
        {
            var deviceManager = this.CreateXCIManager<BL.ViewModelLayer.Models.Device.DeviceModelManager>();
            var device = deviceManager.GetDevice(SN);

            if (device != null)
            {
                return new Common.CommonWebAPI.Models.Response<VerifySNResponseModel>()
                {
                    Body = new VerifySNResponseModel()
                    {
                        MaxZones = device.MaxZones
                    },
                    Result = device != null
                };
            }
            else
            {
                return new Common.CommonWebAPI.Models.Response<VerifySNResponseModel>()
                {
                    Result = false
                };
            }
        }

        [Route("{SN}/Activate")]
        [HttpGet]
        public Common.CommonWebAPI.Models.Response ActivateDevice(string SN)
        {
            var deviceManager = this.CreateXCIManager<BL.ViewModelLayer.Models.Device.DeviceModelManager>();
            var existsDevice = deviceManager.GetDevice(SN);
            if (existsDevice == null)
            {
                var NewDeviceID = deviceManager.AddDevice(SN, null);

                if (NewDeviceID.HasValue)
                {
                    return new Common.CommonWebAPI.Models.Response()
                    {
                        Result = true,
                        Messages = new Common.CommonWebAPI.Models.MessageCodeModel[]
                         {
                              new Common.CommonWebAPI.Models.MessageCodeModel(0,"Created New Device ({0})",NewDeviceID.Value)
                         }
                    };
                }
                else
                {
                    return new Common.CommonWebAPI.Models.Response()
                    {
                        Result = false,
                        Messages = new Common.CommonWebAPI.Models.MessageCodeModel[]
                         {
                              new Common.CommonWebAPI.Models.MessageCodeModel(0,"Failed to Create New Device")
                         }
                    };
                }
            }
            else
            {
                return new Common.CommonWebAPI.Models.Response()
                {
                    Result = true,
                    Messages = new Common.CommonWebAPI.Models.MessageCodeModel[]
                     {
                          new Common.CommonWebAPI.Models.MessageCodeModel(0,"AlreadyExists")
                     }
                };
            }
        }

        [Route("{SN}/Location")]
        [HttpPost]
        public Common.CommonWebAPI.Models.Response UpdateDeviceLocation(string SN, string lat, string lon)
        {
            var deviceManager = this.CreateXCIManager<BL.ViewModelLayer.Models.Device.DeviceModelManager>();
            var result = deviceManager.UpdateDeviceLocation(SN, lat, lon);

            return new Common.CommonWebAPI.Models.Response()
            {
                Result = result
            };
        }
    }

    public class VerifySNResponseModel
    {
        public int MaxZones { get; set; }
    }
}
