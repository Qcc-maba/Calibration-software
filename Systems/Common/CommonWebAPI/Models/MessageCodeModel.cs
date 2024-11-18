using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Maba.Hydra2.Systems.Common.CommonWebAPI.Models
{
    public class MessageCodeModel
    {
        #region properties

        public int Code { get; set; }
        public string Message { get; set; }

        #endregion

        #region ctor

        public MessageCodeModel(int code, string message = null, params object[] args)
        {
            Code = code;
            Message = String.IsNullOrEmpty(message) ? null : String.Format(message, args);
        }

        public MessageCodeModel(string message = null, params object[] args)
            : this(0, message, args)
        {

        }

        #endregion
    }
}