using System;
using System.IO;
using System.Threading.Tasks;
using Microsoft.Owin;
using Owin;
using System.Web.Http;
using System.Web.Mvc;
using Maba.Hydra2.Systems.Common.CommonWebAPI;
using CommonWebAPI = Maba.Hydra2.Systems.Common.CommonWebAPI;
using Maba.Hydra2.Systems.XCIGroup.WebServices.App_Start;

[assembly: OwinStartup(typeof(Maba.Hydra2.Systems.XCIGroup.WebServices.Startup))]

namespace Maba.Hydra2.Systems.XCIGroup.WebServices
{
    public class Startup
    {
        public void Configuration(IAppBuilder app)
        {
            #region read settings 

            var folder = System.Web.Hosting.HostingEnvironment.MapPath("~");
            var _Settings = Connectors.JsonHelpersLibrary.HierarchyFiles.TypeReader.ReadTypeContent<Settings.WebServicesSettings>(folder);

            #region validate settings

            string message = null;

            if (_Settings.ViewModelLayerSettings == null)
            {
                _Settings.ViewModelLayerSettings = new BL.ViewModelLayer.Settings.ViewModelLayerSettings();
            }

            if (_Settings.Properties == null)
            {
                _Settings.Properties = new Settings.GeneralProperties();
            }
            if (_Settings.ViewModelLayerSettings.PETRepositorySettings_ES == null)
            {
                message = "PETRepositorySettings_ES is missing,";
            }

            if (message != null)
            {
                message = "One or more settings are missing. Fix the following: " + message.Substring(0, message.Length - 2);
                throw new SystemException(message);
            }

            #endregion

            _Settings.ViewModelLayerSettings.AdminRepositoryFunc = () =>
            {
                return new DAL.DataAccessLayer.Repositories.Admin.TSQLAdminRepository();
            };

            _Settings.ViewModelLayerSettings.AgricultureRepositoryFunc = () =>
            {
                return new Connectors.WeatherServices.PETProcessing.AgricultureData.ESAgricultureRepository(_Settings.ViewModelLayerSettings.PETRepositorySettings_ES);
            };

            #endregion

            if (_Settings.Properties.DebugMode)
            {
                AreaRegistration.RegisterAllAreas();
            }
            FilterConfig.RegisterGlobalFilters(GlobalFilters.Filters);
            CommonWebApiConfig.DebugMode = _Settings.Properties.DebugMode;
            GlobalConfiguration.Configure((config) =>
            {
                CommonWebApiConfig.Register1(config);
                CommonWebApiConfig.Register2(config, _Settings);
            });

            #region DependencyResolver

            var _DependencyResolver = new CommonWebAPI.DependencyResolves.BaseControllerDependencyResolver<Settings.WebServicesSettings>(_Settings);
            GlobalConfiguration.Configuration.DependencyResolver = _DependencyResolver;

            #endregion

            #region Authentication providers

            app.UseHydra2CommonAuthSettings(_Settings.DataProtectionOptions);

            #endregion
        }
    }
}
