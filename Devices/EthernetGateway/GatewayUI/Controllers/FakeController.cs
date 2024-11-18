using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace GatewayUI.Controllers
{
    [RoutePrefix("Fake")]
    public class FakeController : ApiController
    {
        [HttpGet]
        [Route("NewMAC")]
        public Models.DeviceAllocatedMAC GetNewDeviceMAC()
        {
            return new Models.DeviceAllocatedMAC()
            {
                MAC = "11:22:33:44:55:66"
            };

        }
    }
}
