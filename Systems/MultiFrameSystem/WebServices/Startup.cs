using System;
using Microsoft.Owin;
using Owin;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;
using System.Web.Http;
using System.IO;
using Maba.Hydra2.Systems.Common.CommonWebAPI;
using Maba.Connectors.JsonHelpersLibrary;

[assembly: OwinStartup(typeof(Maba.Hydra2.Systems.MF.WebServices.Startup))]

namespace Maba.Hydra2.Systems.MF.WebServices
{
    public class Startup
    {
        public void Configuration(IAppBuilder app)
        {
            var folder = System.Web.Hosting.HostingEnvironment.MapPath("~");

            var _Settings = Connectors.JsonHelpersLibrary.HierarchyFiles.TypeReader.ReadTypeContent<Settings.WebServicesSettings>(folder);

            #region validate settings 

            string message = null;
            if (_Settings.ViewModelLayerSettings == null)
            {
                _Settings.ViewModelLayerSettings = new BL.ViewModelLayer.Base.ViewModelSettings();
            }

            if (_Settings.ViewModelLayerSettings.KnownDeviceTypes == null || _Settings.ViewModelLayerSettings.KnownDeviceTypes.Length == 0)
            {
                _Settings.ViewModelLayerSettings.BuildDefaultKnownDeviceTypes();
            }

            if (message != null)
            {
                message = "One or more settings are missing. Fix the following: " + message.Substring(0, message.Length - 2);
                throw new SystemException(message);
            }

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

            #region use settings for repositories


            _Settings.ViewModelLayerSettings.DAL_AdminLayer_RepositoriesGenerator = new DAL.AdminLayer.Repositories.RepositoryGenerator()
            {
                Generator_IAccountRepository = () => new DAL.AdminLayer.Repositories.Account.TSQL.TSQLAccountRepository(),
                Generator_IDeviceProcessingRepository = () => new DAL.AdminLayer.Repositories.Device.TSQL.TSQLDeviceProcessingRepository(),
                Generator_IDeviceRepository = () => new DAL.AdminLayer.Repositories.Device.TSQL.TSQLDeviceRepository(),
                Generator_IFolderingRepository = () => new DAL.AdminLayer.Repositories.Foldering.TSQL.TSQLFolderingRepository(),
                Generator_IWeatherRepository = () => new DAL.AdminLayer.Repositories.Weather.TSQL.TSQLIWeatherRepository()
            };

            _Settings.ViewModelLayerSettings.DAL_BulksLayer_RepositoriesGenerator = new DAL.BulksLayer.Repositories.RepositoryGenerator()
            {
                Generator_IInboxMessagesRepository = () => new DAL.BulksLayer.Repositories.InboxMessages.ES.ESInboxMessagesRepository(new DAL.BulksLayer.Repositories.InboxMessages.ES.MessagesESSettings()),
                Generator_IWeatherForecastsRepository = () => new DAL.BulksLayer.Repositories.Weather.ES.ESWeatherRepository(_Settings.ViewModelLayerSettings.WeatherRepositorySettings_ES ?? new DAL.BulksLayer.Repositories.Weather.ES.WeatherESSettings())
            };

            #endregion

            #region Authentication providers

            app.UseHydra2CommonAuthSettings(_Settings.DataProtectionOptions);

            #endregion
        }
    }
}