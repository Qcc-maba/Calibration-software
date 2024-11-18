using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.WebServices.Settings
{
    public class GeneralProperties
    {
        #region Properties

        public bool DebugMode { get; set; } = false;

        public string AccountSystemURI { get; set; }

        #endregion

        #region ctor

        public GeneralProperties()
        {
            AccountSystemURI = "https://account.Maba-smart.com/API";
        }

        #endregion
    }
}
