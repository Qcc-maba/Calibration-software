using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Maba.Hydra2.Systems.Common.CommonWebAPI.Models
{
    public class Response
    {
        public MessageCodeModel[] Messages { get; set; }
        public bool Result { get; set; }

        public Response()
        {
            Result = true;
        }

        public Response(bool result)
        {
            this.Result = result;
        }


        public void AddMessages(params MessageCodeModel[] ms)
        {
            if (this.Messages == null)
            {
                Messages = ms;
            }
            else
            {
                var temp_messages = Messages.Concat(ms);
                Messages = temp_messages.ToArray();
            }

        }
    }
}