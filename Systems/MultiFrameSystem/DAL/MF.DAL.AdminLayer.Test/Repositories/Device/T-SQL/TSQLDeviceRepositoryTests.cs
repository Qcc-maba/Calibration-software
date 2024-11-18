using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories.Device.TSQL;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories.Device.TSQL.Test
{
    [TestClass()]
    public class MF_AdminLayer_Device__TSQLDeviceRepositoryTests
    {
        internal TSQLDeviceRepository rep { get; private set; } = null;
        internal Models.AccountUser _user { get; set; } = null;
        private Random rand = new Random();

        private long User_SiteID = -1;

        private Models.DeviceType[] _DeviceTypes = null;
        private Models.GlobalizationZone[] _GlobalizationZones = null;
        internal List<Models.MainDevice> _CreatedDevices = new List<Models.MainDevice>();

        #region ctor

        public MF_AdminLayer_Device__TSQLDeviceRepositoryTests()
        {
            rep = new TSQLDeviceRepository();
            rand = new Random();

            _DeviceTypes = rep.GetDeviceTypes();

            using (var rep_account = new Account.TSQL.TSQLAccountRepository())
            {
                _GlobalizationZones = rep_account.GetGlobalizationZones(null);
            }
        }

        #endregion

        #region private methods

        internal Models.MainDevice _GetDevice(int? debugNum = null, long? parentSiteID = null, bool deleteIfExists = true)
        {
            if (!debugNum.HasValue)
            {
                debugNum = rand.Next(1000, 9999);
            }

            string SN = "DEBUG" + ($"0{debugNum}".PadLeft(11, '0'));
            //check if already exists
            var _d = rep.GetDevice(SN);
            if (_d != null)
            {
                if (deleteIfExists)
                {
                    Assert.IsTrue(rep.DeleteDevice(SN, _d.DeviceID));
                    _CreatedDevices.RemoveAll(d => d.SN == SN);
                }
                else
                {
                    _CreatedDevices.Add(_d);
                    return _d;
                }
            }

            //************************* Create Device ********************************
            string name = $"Test Device-{string.Concat(SN.Reverse()).Substring(0, 4)}-{rand.Next(10, 1000)}";
            int statusID = rand.Next(0, 1);
            int maxZones = rand.Next(1, 100);
            string lat = $"{rand.Next(10, 99)}.{rand.Next(10, 99)}";
            string lon = $"{rand.Next(10, 99)}.{rand.Next(10, 99)}";
            int typeID = _DeviceTypes[rand.Next(0, _DeviceTypes.Length - 1)].TypeID;

            long DeviceID = rep.CreateDevice(SN,
                             name,
                             parentSiteID,
                             statusID,
                             lat,
                             lon,
                             typeID,
                             maxZones);

            Assert.IsTrue(DeviceID >= 0);

            var _device = rep.GetDevice(SN);
            _CreatedDevices.Add(_device);

            //compare
            Assert.AreEqual(_device.DeviceID, DeviceID);
            Assert.AreEqual(_device.SN, SN);
            Assert.AreEqual(_device.Name, name);
            Assert.AreEqual(_device.ParentSiteID, parentSiteID);
            Assert.AreEqual(_device.StatusID, statusID);
            Assert.AreEqual(_device.DeviceTypeID, typeID);
            Assert.AreEqual(_device.MaxZones, maxZones);
            Assert.IsNull(_device.TotalActivatedZones);

            Assert.AreEqual(_device.Map_Latitude, lat);
            Assert.AreEqual(_device.Map_Longitude, lon);

            return _device;
        }

        #endregion

        #region Init & Clean

        [TestInitialize]
        public void Init()
        {
            GeneralHelper.Clean();

            _user = GeneralHelper.CreateTesterUser();

            using (var rep_foldering = new Foldering.TSQL.TSQLFolderingRepository())
            {
                var newProject = new Models.MainSite()
                {
                    Name = $"MyProject-{rand.Next(10, 1000)}"
                };

                User_SiteID = rep_foldering.AddProject(newProject, _user.UserID);
            }
            _CreatedDevices.Clear();
        }

        [TestCleanup]
        public void Clean()
        {
            //when User_SiteID=-1 it means this Test-Class has been never initiated by Init method
            //(for example - because it was created by another Test-Class like FolderingRepositoryTests)
            if (User_SiteID != -1)
            {
                using (var rep_foldering = new Foldering.TSQL.TSQLFolderingRepository())
                {
                    Assert.IsTrue(rep_foldering.DeleteProject(User_SiteID, _user.UserID));
                }

                using (var rep_account = new Account.TSQL.TSQLAccountRepository())
                {
                    Assert.IsTrue(rep_account.DeleteUser(_user.UserID));
                }
            }

            _user = null;

            foreach (var d in _CreatedDevices)
            {
                if (d == null)
                    continue;
                Assert.IsTrue(rep.DeleteDevice(d.SN, d.DeviceID));
            }
            _CreatedDevices.Clear();
        }

        #endregion

        #region Tests

        [TestMethod]
        public void DeviceInfoWithParent_Test()
        {
            bool IsDetachedDevice = false;

            //device attached to site
            IsDetachedDevice = false;
            var attachedDevice = _GetDevice(parentSiteID: User_SiteID);

            var deviceInfo_attached = rep.GetDeviceInfo(_user.UserID, attachedDevice.SN, out IsDetachedDevice);
            Assert.IsNotNull(deviceInfo_attached);
            Assert.IsFalse(IsDetachedDevice);

            Assert.AreEqual(deviceInfo_attached.DeviceName, attachedDevice.Name);
            Assert.AreEqual(deviceInfo_attached.SN, attachedDevice.SN);
            Assert.AreEqual(deviceInfo_attached.DeviceID, attachedDevice.DeviceID);
            Assert.AreEqual(deviceInfo_attached.DeviceTypeID, attachedDevice.DeviceTypeID);
            Assert.AreEqual(deviceInfo_attached.DeviceTypeName, attachedDevice.DeviceTypeName);
            Assert.AreEqual(deviceInfo_attached.CreationDate, attachedDevice.CreationDate);
            Assert.AreEqual(deviceInfo_attached.FirmwareVersion, attachedDevice.FirmwareVersion);
            Assert.AreEqual(deviceInfo_attached.HoldUntilDate, attachedDevice.HoldUntilDate);
            Assert.AreEqual(deviceInfo_attached.IsAlertsEnabled, attachedDevice.IsAlertsEnabled);
            Assert.AreEqual(deviceInfo_attached.LastModifiedDate, attachedDevice.LastModifiedDate);
            Assert.AreEqual(deviceInfo_attached.Map_Latitude, attachedDevice.Map_Latitude);
            Assert.AreEqual(deviceInfo_attached.Map_Longitude, attachedDevice.Map_Longitude);
            Assert.AreEqual(deviceInfo_attached.ParentSiteID, attachedDevice.ParentSiteID);

            Assert.AreEqual(deviceInfo_attached.TotalActivatedZones, attachedDevice.TotalActivatedZones);
            Assert.AreEqual(deviceInfo_attached.MaxZones, attachedDevice.MaxZones);


            //device not-attached (shouldn't return back)
            IsDetachedDevice = false;
            var dettachedDevice = _GetDevice();
            var deviceInfo_detached = rep.GetDeviceInfo(_user.UserID, dettachedDevice.SN, out IsDetachedDevice);
            Assert.IsTrue(IsDetachedDevice);
            Assert.IsNull(deviceInfo_detached);
        }

        [TestMethod]
        public void MainDevice_Test()
        {
            var d = _GetDevice();

            Assert.IsNotNull(d);
            Assert.IsTrue(d.DeviceID > 0);
        }

        [TestMethod()]
        public void CreateDevice_Test()
        {
            var d = _GetDevice(0);

            Assert.IsNotNull(d);
            Assert.IsTrue(d.DeviceID > 0);
        }

        [TestMethod()]
        public void GetDeviceTypes_Test()
        {
            //no filtering
            var types = rep.GetDeviceTypes();
            Assert.IsNotNull(types);

            Assert.IsTrue(types.Length > 0);

            foreach (var t in types)
            {
                Assert.IsNotNull(t.Name);
            }

            //filtered
            foreach (var t in types)
            {
                var specificType = rep.GetDeviceTypes(t.Name);
                Assert.IsNotNull(specificType);
                Assert.AreEqual(1, specificType.Length);

                Assert.AreEqual(t.Name, specificType[0].Name);
                Assert.AreEqual(t.TypeID, specificType[0].TypeID);
            }
        }

        //[TestMethod()]
        //public void GetDeviceModels_Test()
        //{
        //    Assert.IsNotNull(_DeviceModels);

        //    Assert.IsTrue(_DeviceModels.Length > 0);
        //}

        [TestMethod()]
        public void UpdateDeviceName_Test()
        {
            var d = _GetDevice(1);

            string newName = $"NewName_{rand.Next(1, 10000)}";

            Assert.IsTrue(rep.UpdateDeviceName(d.SN, newName));

            var device2 = rep.GetDevice(d.SN);
            Assert.AreEqual(device2.Name, newName);
        }

        [TestMethod()]
        public void GetDevice_Test()
        {
            var _device = _GetDevice(4);

            Models.MainDevice _secondDevice = null;
            for (int i = 0; i < 2; i++)
            {

                _secondDevice = i == 0 ?
                                        //test by ID
                                        rep.GetDevice(_device.DeviceID) :
                                        //test by SN
                                        rep.GetDevice(_device.SN);


                Assert.AreEqual(_device.DeviceID, _secondDevice.DeviceID);
                Assert.AreEqual(_device.SN, _secondDevice.SN);
                Assert.AreEqual(_device.Name, _secondDevice.Name);
                Assert.AreEqual(_device.ParentSiteID, _secondDevice.ParentSiteID);
                Assert.AreEqual(_device.StatusID, _secondDevice.StatusID);
                Assert.AreEqual(_device.TotalActivatedZones, _secondDevice.TotalActivatedZones);
                Assert.AreEqual(_device.MaxZones, _secondDevice.MaxZones);

                Assert.AreEqual(_device.Map_Latitude, _secondDevice.Map_Latitude);
                Assert.AreEqual(_device.Map_Longitude, _secondDevice.Map_Longitude);
            }
        }

        [TestMethod()]
        public void GetDeviceInfo_Test()
        {
            var sites = new long?[] { null, User_SiteID };
            foreach (var _siteID in sites)
            {
                var d = _GetDevice(null, _siteID);

                bool isDetachedDevice = false;
                var device_info = rep.GetDeviceInfo(_user.UserID, d.SN, out isDetachedDevice);

                Assert.AreEqual(_siteID.HasValue, !isDetachedDevice);

                if (isDetachedDevice)
                {
                    Assert.IsNull(device_info);
                }
                else
                {
                    Assert.IsNotNull(device_info);

                    Assert.AreEqual(device_info.SiteID, User_SiteID);
                    Assert.AreEqual(device_info.DeviceTypeName, d.DeviceTypeName);
                    Assert.AreEqual(device_info.DeviceTypeID, d.DeviceTypeID);

                    Assert.AreNotEqual(0, device_info.Level);
                    Assert.IsTrue(device_info.RoleControlRT);
                    Assert.IsTrue(device_info.RoleModify);
                    Assert.IsTrue(device_info.RoleViewOnly);
                    Assert.IsTrue(device_info.RoleAdmin);

                    //LinkID and IsVerified were removed
                    //Assert.IsTrue(device_info.LinkID > 0);
                    // Assert.IsTrue(device_info.IsVerified.GetValueOrDefault(false));
                }
            }
        }

        [TestMethod()]
        public void GetDeviceType_Test()
        {
            var d = _GetDevice(5, User_SiteID);

            var type = rep.GetDeviceType(d.SN);

            Assert.AreEqual(type.TypeID, d.DeviceTypeID);
            Assert.AreEqual(type.Name, d.DeviceTypeName);
        }

        [TestMethod()]
        public void AttachDeviceToSite_Test()
        {
            var d = _GetDevice(2);
            var device_original = rep.GetDevice(d.SN);
            var r = new Random();

            var _Sites = new long?[] { null, User_SiteID, null };

            foreach (var siteID in _Sites)
            {
                string lat = (30 + r.NextDouble()).ToString("f3");
                string lon = (32 + r.NextDouble()).ToString("f3");

                Assert.IsTrue(rep.AttachDeviceToSite(device_original.DeviceID, siteID, lat, lon));

                var device = rep.GetDevice(d.SN);
                Assert.IsNotNull(device);

                //make sure all core settings are the same
                Assert.AreEqual(device.Name, device_original.Name);
                Assert.AreEqual(device.DeviceID, device_original.DeviceID);
                Assert.AreEqual(device.SN, device_original.SN);

                //make sure new settings were set successfully
                Assert.AreEqual(device.Map_Longitude, lon);
                Assert.AreEqual(device.Map_Latitude, lat);
                Assert.AreEqual(device.ParentSiteID, siteID);
            }
        }

        [TestMethod()]
        public void UpdateAlertsEnabled_Test()
        {
            var d = _GetDevice(8);
            var states = new bool[] { false, true, false, true };

            for (int i = 0; i < states.Length; i++)
            {
                Assert.IsTrue(rep.UpdateAlertsEnabled(d.SN, states[i]));

                Assert.AreEqual(rep.GetDevice(d.SN).IsAlertsEnabled, states[i]);
            }
        }

        [TestMethod()]
        public void GetDeviceAlertSettings_Test()
        {
            var d = _GetDevice();

            var alerts_settings = rep.GetDeviceAlertSettings(d.SN);
            Assert.IsTrue(alerts_settings == null || alerts_settings.Length == 0);

            var alert_settings = new Models.DeviceAlertSettings()
            {
                AlertCode = 0,
                DeviceID = d.DeviceID,
                IsEmailEnable = true,
                IsEnable = false,
                IsSMSEnable = true
            };

            for (int i = 0; i < 2; i++)
            {
                alert_settings.IsEmailEnable = !alert_settings.IsEmailEnable;
                alert_settings.IsEnable = !alert_settings.IsEnable;
                alert_settings.IsSMSEnable = !alert_settings.IsSMSEnable;

                Assert.IsTrue(rep.UpdateDeviceAlertSettings(d.SN, alert_settings));

                //check saving
                var compareAlerts_setting = rep.GetDeviceAlertSettings(d.SN);
                Assert.IsNotNull(compareAlerts_setting);
                Assert.AreEqual(compareAlerts_setting.Length, 1);
            }
        }

        [TestMethod()]
        public void UpdateDeviceAlertSettings_Test()
        {
            var d = _GetDevice(10);

            int totalAlerts = 10;
            var alerts = new List<Models.DeviceAlertSettings>();
            for (int i = 0; i < totalAlerts; i++)
            {
                var alert_settings = new Models.DeviceAlertSettings()
                {
                    AlertCode = i,
                    DeviceID = d.DeviceID,
                    IsEmailEnable = (i % 2 != 0),
                    IsEnable = (i % 2 == 0),
                    IsSMSEnable = (i % 2 != 0)
                };

                alerts.Add(alert_settings);
                Assert.IsTrue(rep.UpdateDeviceAlertSettings(d.SN, alert_settings));
            }

            //check saving
            var compareAlerts_setting = rep.GetDeviceAlertSettings(d.SN)
                    .OrderBy(a => a.AlertCode)
                    .ToArray();
            Assert.IsNotNull(compareAlerts_setting);
            Assert.AreEqual(compareAlerts_setting.Length, totalAlerts);

            for (int i = 0; i < totalAlerts; i++)
            {
                Assert.AreEqual(i, compareAlerts_setting[i].AlertCode);
                Assert.AreEqual(d.DeviceID, compareAlerts_setting[i].DeviceID);
                Assert.AreEqual(alerts[i].IsEmailEnable, compareAlerts_setting[i].IsEmailEnable);
                Assert.AreEqual(alerts[i].IsEnable, compareAlerts_setting[i].IsEnable);
                Assert.AreEqual(alerts[i].IsSMSEnable, compareAlerts_setting[i].IsSMSEnable);
            }
        }



        #endregion
    }
}
