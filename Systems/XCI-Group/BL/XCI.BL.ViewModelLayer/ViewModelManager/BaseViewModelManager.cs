using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.ViewModelManager
{
    public abstract class BaseViewModelManager : IDisposable
    {
        #region properties

        public Settings.ViewModelLayerSettings CurrentSettings { get; protected set; }

        #endregion

        #region ctor

        public BaseViewModelManager(Settings.ViewModelLayerSettings currentSettings)
        {
            CurrentSettings = currentSettings;
        }

        #endregion

        #region IDisposable members

        public void Dispose()
        {
            OnDispose();
        }

        #endregion

        #region abstract methods

        protected abstract void OnDispose();

        #endregion
    }
}
