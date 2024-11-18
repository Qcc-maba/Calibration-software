using System;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using System.Web.Http;
using Newtonsoft.Json.Linq;
using Identity2 = Maba.AccountSystem.AspNetIdentity.Identity2;
using System.IO;
using System.Net.Http.Headers;
using Maba.Hydra2.Systems.Common.CommonWebAPI.Controllers;
using Maba.Hydra2.Systems.Common.CommonWebAPI.Models;

namespace Maba.AccountSystem.WebServices.Contollers
{
    [RoutePrefix("Types")]
    [Authorize]
    public class TypesController : BaseController
    {
        [Route("Roles")]
        [HttpGet]
        public async Task<Response<Identity2.BL.Models.UserRoleModel[]>> GetRoles()
        {
            var currentUserRolesResult = await this.UserManager.UserRoles_Roles(CurrentUser.UserID);

            if (currentUserRolesResult.Succeeded)
            {
                return new Response<AspNetIdentity.Identity2.BL.Models.UserRoleModel[]>()
                {
                    Result = true,
                    Body = currentUserRolesResult.Result.ToArray()
                };
            }

            throw this.ThrowHttpResponseWithResultException(
                                                    new MessageCodeModel[]
                                                    {
                                                        new MessageCodeModel(0, "No Roles were found for current user.")
                                                    },
                                                    currentUserRolesResult,
                                                    HttpStatusCode.InternalServerError);
        }



        [Route("TimesZones")]
        [HttpGet]
        public async Task<Response<Identity2.BL.Models.SystemTimeZoneModel[]>> GetTimesZone()
        {
            var zonesResult = await this.UserManager.System_TimeZonesAsync();

            if (zonesResult.Succeeded)
            {
                return new Response<AspNetIdentity.Identity2.BL.Models.SystemTimeZoneModel[]>()
                {
                    Result = true,
                    Body = zonesResult.Result
                };
            }

            throw this.ThrowHttpResponseWithResultException(
                                                    new MessageCodeModel[]
                                                    {
                                                        new MessageCodeModel(0, "No Time zone found")
                                                    },
                                                    zonesResult,
                                                    HttpStatusCode.InternalServerError);
        }

        [Route("UIFormats")]
        [HttpGet]
        public async Task<Response<Identity2.BL.Models.SystemUIFormatModel[]>> GetUIFormats()
        {
            var uiFormatsResult = await this.UserManager.System_UIFormatsAsync();

            if (uiFormatsResult.Succeeded)
            {
                return new Response<Identity2.BL.Models.SystemUIFormatModel[]>()
                {
                    Body = uiFormatsResult.Result,
                    Result = true
                };
            }

            throw this.ThrowHttpResponseWithResultException(
                                                    new MessageCodeModel[]
                                                    {
                                                        new MessageCodeModel(0, "No UIFormat found")
                                                    },
                                                    uiFormatsResult,
                                                    HttpStatusCode.InternalServerError);
        }

        [AllowAnonymous]
        [Route("TemperatureUnits")]
        [HttpGet]
        public async Task<Response<Identity2.BL.Models.SystemTemperatureUnitModel[]>> GetTemperatureUnit()
        {
            var uiFormatsResult = await this.UserManager.System_TemperatureUnitsAsync();

            if (uiFormatsResult.Succeeded)
            {
                return new Response<Identity2.BL.Models.SystemTemperatureUnitModel[]>()
                {
                    Body = uiFormatsResult.Result,
                    Result = true
                };
            }

            throw this.ThrowHttpResponseWithResultException(
                                                    new MessageCodeModel[]
                                                    {
                                                        new MessageCodeModel(0, "No Temperature Unit found")
                                                    },
                                                    uiFormatsResult,
                                                    HttpStatusCode.InternalServerError);
        }

        [Route("All")]
        [HttpGet]
        public async Task<HttpResponseMessage> GetSystemTypesModel()
        {
            var response = new Response<Identity2.BL.Models.SystemTypesModel>()
            {
                Body = new Identity2.BL.Models.SystemTypesModel()
                {
                    TemperatureUnits = (await this.UserManager.System_TemperatureUnitsAsync()).Result,
                    UIFormats = (await this.UserManager.System_UIFormatsAsync()).Result,
                    TimeZones = (await this.UserManager.System_TimeZonesAsync()).Result
                },
                Result = true
            };

            var httpResponse = Request.CreateResponse(HttpStatusCode.OK, response);
            httpResponse.Headers.CacheControl = new CacheControlHeaderValue()
            {
                Public = true,
                MaxAge = new TimeSpan(1, 0, 0, 0)
            };

            return httpResponse;
        }
    }
}
