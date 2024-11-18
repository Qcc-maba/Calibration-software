using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.EmailServices.Tests.MailTranformers
{
    class TestHost
    {
        public string Template_filename { get; set; }
        public object Data { get; set; }
        public MailTemplateTranformers.ParameterValue[] Parameters { get; set; }
    }
}
