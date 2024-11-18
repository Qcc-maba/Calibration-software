using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.Common.CommonWebAPI.MessageHandlers
{
    public class ExceptionDetailsModel
    {
        public string Message { get; set; }
        public string ExceptionType { get; set; }
        public string StackTrace { get; set; }
        public string Response { get; set; }

    }

    public class ExceptionModel
    {
        public string Message { get; set; }
        public string ExceptionType { get; set; }
    }
}

