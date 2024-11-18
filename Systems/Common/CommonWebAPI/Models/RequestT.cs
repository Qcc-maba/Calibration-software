using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Maba.Hydra2.Systems.Common.CommonWebAPI.Models
{
    public class Request<T> : Request
    {
        public T Body { get; set; }

        public Request()
            : base()
        {
        }
    }
}