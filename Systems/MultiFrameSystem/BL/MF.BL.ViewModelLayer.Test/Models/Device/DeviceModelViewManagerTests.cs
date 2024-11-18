using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Device;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Device.Test
{
    [TestClass()]
    public class DeviceModelViewManagerTests
    {
        #region private methods

        private DeviceModelViewManager _CreateManager()
        {
            var settings = new Base.ViewModelSettings()
            {
                DAL_BulksLayer_RepositoriesGenerator = new DAL.BulksLayer.Repositories.RepositoryGenerator()
            };

            settings.DAL_AdminLayer_RepositoriesGenerator = new DAL.AdminLayer.Repositories.RepositoryGenerator()
            {
                Generator_IAccountRepository = () => new DAL.AdminLayer.Repositories.Account.TSQL.TSQLAccountRepository(),
                Generator_IDeviceProcessingRepository = () => new DAL.AdminLayer.Repositories.Device.TSQL.TSQLDeviceProcessingRepository(),
                Generator_IDeviceRepository = () => new DAL.AdminLayer.Repositories.Device.TSQL.TSQLDeviceRepository(),
                Generator_IFolderingRepository = () => new DAL.AdminLayer.Repositories.Foldering.TSQL.TSQLFolderingRepository(),
                Generator_IWeatherRepository = () => new DAL.AdminLayer.Repositories.Weather.TSQL.TSQLIWeatherRepository()
            };

            var manager = new DeviceModelViewManager(settings);
            manager.CurrentSettings.BuildDefaultKnownDeviceTypes();

            return manager;
        }

        #endregion

        [TestMethod()]
        public void DeviceModelViewManager_Test()
        {
            Assert.Fail();
        }

        [TestMethod()]
        public void AttachDeviceToSite_Test()
        {
            Assert.Fail();
        }

        [TestMethod()]
        public void UpdateDevice_AlertsSettings_Test()
        {
            Assert.Fail();
        }

        [TestMethod()]
        public void GetDeviceAlertSettings_Test()
        {
            Assert.Fail();
        }

        [TestMethod()]
        public void UpdateDeviceAlertSettings_Test()
        {
            Assert.Fail();
        }

        [TestMethod()]
        public void GetDevice_Test()
        {
            Assert.Fail();
        }

        [TestMethod()]
        public void UnlinkDevice_Test()
        {
            Assert.Fail();
        }

        [TestMethod()]
        public void GetDeviceType_Test()
        {
            Assert.Fail();
        }

        private T Wait<T>(Task<T> func)
        {
            Assert.IsTrue(func.Wait(10000));

            return func.Result;
        }
        [TestMethod()]
        public void FindDeviceType_Test()
        {
            var manager = _CreateManager();

            foreach (var t in manager.CurrentSettings.KnownDeviceTypes)
            {
                foreach (var ex in t.SN_Examples)
                {
                    Assert.IsTrue(t.IsMatch(ex));
                }
            }


            foreach (var t in manager.CurrentSettings.KnownDeviceTypes)
            {
                foreach (var ex in t.SN_Examples)
                {
                    var knownType = Wait(manager.FindDeviceTypeAsync(0, ex, null));

                    Assert.IsNotNull(knownType);
                    Assert.IsNotNull(knownType.Status);
                    Assert.IsNotNull(knownType.SystemDeviceType);

                    Assert.AreEqual(knownType.SystemDeviceType.Name, t.DeviceTypeName);
                }
            }
        }

        [TestMethod()]
        public void UpdateDeviceName_Test()
        {
            Assert.Fail();
        }
    }
}