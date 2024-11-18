using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Maba.Hydra2.Systems.Common.CommonWebAPI.Models
{
    public class Response<T> : Response
    {
        public T Body { get; set; }
        public Response(T result)
            : base(true)
        {
            this.Body = result;
        }

        public Response()
            : base()
        {

        }
    }
}