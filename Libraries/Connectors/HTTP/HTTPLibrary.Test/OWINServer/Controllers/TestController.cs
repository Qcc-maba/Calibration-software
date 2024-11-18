using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace Maba.Connectors.HTTPLibrary.Test.WebApplication.Controllers
{
    [RoutePrefix("api/Test")]
    public class TestController : ApiController
    {
        [HttpGet]
        [Route("Calc")]
        public Models.Class1 TestCalc(int x, int y)
        {
            return new Models.Class1()
            {
                ID = x + y,
                Name = (x * y).ToString(),
                Headers = this.Request.Headers
                        .Select(h => String.Format("{0}:{1}", h.Key, h.Value.FirstOrDefault()))
                        .ToArray()
            };
        }

        private Models.Class1 ManipulateData(Models.Class1 data)
        {
            return new Models.Class1()
            {
                ID = data != null ? data.ID : 100,
                Name = data != null ? data.Name : "<NULL>",
                Headers = this.Request.Headers
                        .Select(h => String.Format("{0}:{1}", h.Key, h.Value.FirstOrDefault()))
                        .Concat(data != null && data.Headers != null ? data.Headers : new string[0])
                        .ToArray()
            };
        }

        [HttpPost]
        [Route("SendData")]
        public Models.Class1 SendData_Post(int x, int y, Models.Class1 data)
        {
            var d = ManipulateData(data);
            d.Method = "POST";

            return d;
        }

        [HttpDelete]
        [Route("SendData")]
        public Models.Class1 SendData_Delete(int x, int y, Models.Class1 data)
        {
            var d = ManipulateData(data);
            d.Method = "DELETE";

            return d;
        }
    }
}
