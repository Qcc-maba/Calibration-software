using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;
using CommonWebAPI = Maba.Hydra2.Systems.Common.CommonWebAPI;

namespace Maba.Hydra2.Systems.XCIGroup.WebServices.Controllers
{
    public class BaseController : CommonWebAPI.Controllers.BaseController<Settings.WebServicesSettings>
    {
        #region protected methods

        protected bool RoleModifySN(string SN)
        {
            return true;
        }


        protected bool ViewOnlySN(string SN)
        {
            return true;
        }

        protected T CreateXCIManager<T>() where T : BL.ViewModelLayer.ViewModelManager.BaseViewModelManager
        {
            var manager = Activator.CreateInstance(typeof(T), this.Carrier.ViewModelLayerSettings) as BL.ViewModelLayer.ViewModelManager.BaseViewModelManager;

            return (T)manager;
        }

        #endregion


    }
}
