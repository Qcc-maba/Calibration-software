using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Base
{
    public abstract class BaseViewModelManager : IDisposable
    {
        #region properties

        public ViewModelSettings CurrentSettings { get; private set; }

        #endregion

        #region ctor

        public BaseViewModelManager(ViewModelSettings settings)
        {
            CurrentSettings = settings;
        }

        #endregion

        #region abstract members

        protected abstract void OnDispose();

        #endregion

        #region protected methods

        protected DAL.AdminLayer.Models.SiteInfo GetSiteInfo(long UserID, long SiteID)
        {
            //we don't need to validate as SiteInfo covers the validation in DAL
            using (var folderingRepository = this.CurrentSettings.DAL_AdminLayer_RepositoriesGenerator.Generator_IFolderingRepository())
            {
                var siteInfo = folderingRepository.GetSiteInfo(UserID, SiteID);

                if (siteInfo == null)
                {
                    throw new Exceptions.SecurityException("This site is Forbidden", Exceptions.SecurityException.EXCEPTION_SECURITY);
                }

                return siteInfo;
            }
        }

        protected DAL.AdminLayer.Models.TreeNode ValidateOwnership_Project(long UserID, long ProjectID)
        {
            return ValidateOwnership_Site(UserID, ProjectID);
        }

        protected DAL.AdminLayer.Models.TreeNode ValidateOwnership_Site(long UserID, long SiteID)
        {
            using (var folderingRepository = this.CurrentSettings.DAL_AdminLayer_RepositoriesGenerator.Generator_IFolderingRepository())
            {
                var ShareData = folderingRepository.ValidateOwnership_Site(UserID, SiteID);
                if (ShareData == null || !ShareData.IsVerified.Value)
                    throw new Exceptions.SecurityException("This site is Forbidden", Exceptions.SecurityException.EXCEPTION_SECURITY);

                return ShareData;
            }
        }

        protected DeviceValidationResult ValidateOwnership_SN(long UserID, string SN, bool throwExceptions = true)
        {
            var result = new DeviceValidationResult();

            using (var deviceRepository = this.CurrentSettings.DAL_AdminLayer_RepositoriesGenerator.Generator_IDeviceRepository())
            {
                bool detachedDevice = false;
                var deviceInfo = deviceRepository.GetDeviceInfo(UserID, SN, out detachedDevice);

                if (detachedDevice)
                {
                    //check if this user has the right for detached devices
                    var device = deviceRepository.GetDevice(SN);
                    result.DetachedDevice = device;
                    result.IsDetachedDevice = true;
                    result.IsValid = true;
                }
                else
                {
                    if (deviceInfo == null || deviceInfo.SN != SN)
                    {
                        if (throwExceptions)
                        {
                            throw new Exceptions.SecurityException("This SN is Forbidden (A)", Exceptions.SecurityException.EXCEPTION_SECURITY);
                        }
                        else
                        {
                            result.IsValid = false;
                        }
                    }
                    else
                    {
                        result.IsDetachedDevice = false;
                        result.AttachedDevice = deviceInfo;
                        result.IsValid = true;
                    }
                }

                if (!result.IsValid && throwExceptions)
                {
                    throw new Exceptions.SecurityException("This SN is Forbidden (B)", Exceptions.SecurityException.EXCEPTION_SECURITY);
                }

                return result;
            }
        }
        /*protected DAL.AdminLayer.Models.SiteInfo GetDeviceInfo(long UserID, string SN)
        {
            using (var deviceRepository = this.CurrentSettings.DAL_AdminLayer_RepositoriesGenerator.Generator_IDeviceRepository())
            {
                var ShareData = deviceRepository.GetDeviceInfo(UserID, SN);
                if (ShareData == null)
                {
                    throw new Exceptions.SecurityException("This sn is Forbidden", Exceptions.SecurityException.EXCEPTION_SECURITY);
                }

                return ShareData;
            }
        }*/

        protected void Validate_RoleModify(DeviceValidationResult validationResult)
        {
            if (validationResult.IsDetachedDevice)
            {
                if (validationResult.DetachedDevice == null)
                    throw new Exceptions.SecurityException("Role Modify Forbidden(A)", Exceptions.SecurityException.EXCEPTION_MODIFY);
            }
            else
            {
                if (validationResult.AttachedDevice == null || (!validationResult.AttachedDevice.RoleModify && !validationResult.AttachedDevice.RoleAdmin))
                    throw new Exceptions.SecurityException("Role Modify Forbidden(B)", Exceptions.SecurityException.EXCEPTION_MODIFY);
            }
        }

        protected void Validate_RoleModify(DAL.AdminLayer.Models.TreeNode data)
        {
            if (!data.RoleModify && !data.RoleAdmin)
                throw new Exceptions.SecurityException("Role Modify Forbidden", Exceptions.SecurityException.EXCEPTION_MODIFY);
        }

        protected void Validate_RoleView(DeviceValidationResult validationResult)
        {
            if (validationResult.IsDetachedDevice)
            {
                if (validationResult.DetachedDevice == null)
                    throw new Exceptions.SecurityException("Role View Forbidden(A)", Exceptions.SecurityException.EXCEPTION_MODIFY);
            }
            else
            {
                if (validationResult.AttachedDevice == null || (!validationResult.AttachedDevice.RoleModify && !validationResult.AttachedDevice.RoleAdmin && !validationResult.AttachedDevice.RoleViewOnly && !validationResult.AttachedDevice.RoleModify))
                    throw new Exceptions.SecurityException("Role View Forbidden(B)", Exceptions.SecurityException.EXCEPTION_MODIFY);
            }
        }

        protected void Validate_RoleView(DAL.AdminLayer.Models.TreeNode data)
        {
            if (data == null || data.IsVerified == null && !data.IsVerified.Value)
                throw new Exceptions.SecurityException("Role View Only Forbidden", Exceptions.SecurityException.EXCEPTION_VIEW);
        }

        protected void Validate_RoleAdmin(DeviceValidationResult validationResult)
        {
            if (validationResult.IsDetachedDevice)
            {
                if (validationResult.DetachedDevice == null)
                    throw new Exceptions.SecurityException("Role View Forbidden(A)", Exceptions.SecurityException.EXCEPTION_MODIFY);
            }
            else
            {
                if (validationResult.AttachedDevice == null || !validationResult.AttachedDevice.RoleModify)
                    throw new Exceptions.SecurityException("Role Admin Forbidden(B)", Exceptions.SecurityException.EXCEPTION_MODIFY);
            }
        }

        protected void Validate_RoleAdmin(DAL.AdminLayer.Models.TreeNode data)
        {
            if (!data.RoleAdmin)
                throw new Exceptions.SecurityException("Role Admin Forbidden", Exceptions.SecurityException.EXCEPTION_ADMIN);
        }

        #endregion

        #region IDisposable members

        public void Dispose()
        {
            OnDispose();
        }

        #endregion
    }
}
