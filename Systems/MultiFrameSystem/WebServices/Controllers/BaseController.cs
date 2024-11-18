using System;
using ViewModelLayer = Maba.Hydra2.Systems.MF.BL.ViewModelLayer;
using CommonWebAPI = Maba.Hydra2.Systems.Common.CommonWebAPI;
using System.Security.Claims;

namespace Maba.Hydra2.Systems.MF.WebServices.Controllers
{
    public abstract class BaseController : CommonWebAPI.Controllers.BaseController<Settings.WebServicesSettings>
    {
        protected const string MF_CLAIM = "MFOnlineToken";


        #region properties

        protected T CreateMFManager<T>() where T : ViewModelLayer.Base.BaseViewModelManager
        {
            var manager = Activator.CreateInstance(typeof(T), this.Carrier.ViewModelLayerSettings) as ViewModelLayer.Base.BaseViewModelManager;

            return (T)manager;
        }

        #endregion

        protected override bool ValidateIdentity(ClaimsIdentity identity)
        {
            return identity.HasClaim(c => c.Type == MF_CLAIM);
        }

    }
}
