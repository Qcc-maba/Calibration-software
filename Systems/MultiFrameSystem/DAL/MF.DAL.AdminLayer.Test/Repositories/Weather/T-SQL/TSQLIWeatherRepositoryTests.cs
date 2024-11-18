using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories.Weather.TSQL;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories.Weather.TSQL.Test
{
    [TestClass()]
    public class MF_AdminLayer_Weather__TSQLIWeatherRepositoryTests
    {
        Random rand = new Random();

        #region ctor

        public MF_AdminLayer_Weather__TSQLIWeatherRepositoryTests()
        {

        }

        #endregion

        #region private methods

        //private long _UserID = -1;
        private long _SiteID = -1;
        private long _DeviceID = -1;
        private string _SN = "";

        private IWeatherRepository _CreateConnector()
        {
            var connector = new TSQLIWeatherRepository();

            return connector;
        }
        private void CompareAlgorithm_P1(WeatherAlgorithm_P1 P1, WeatherAlgorithm_P1 P2)
        {
            Assert.IsNotNull(P1);
            Assert.IsNotNull(P2);

            Assert.AreEqual(P1.IsEnabled, P2.IsEnabled);
            Assert.AreEqual(P1.ManualValues, P2.ManualValues);

            Assert.AreEqual(P1.AlgorithmID, P2.AlgorithmID);
            Assert.AreEqual(P1.AlgorithmTypeID, P2.AlgorithmTypeID);
            Assert.AreEqual(P1.ChangeHumidity_Per5Precent, P2.ChangeHumidity_Per5Precent);
            Assert.AreEqual(P1.ChangeTemp_Per5Deg, P2.ChangeTemp_Per5Deg);
            Assert.AreEqual(P1.HottestMonthTemp, P2.HottestMonthTemp);
            Assert.AreEqual(P1.TemperatureUnit, P2.TemperatureUnit);

            Assert.AreEqual(P1.NormalHumidity, P2.NormalHumidity);
            Assert.AreEqual(P1.PreciptationTreshold, P2.PreciptationTreshold);
        }

        private WeatherAlgorithm_P1 _Create_RandomAlgorithm_P1()
        {
            var algorithm_P1 = new WeatherAlgorithm_P1()
            {
                IsEnabled = rand.Next(0, 1000) % 2 == 0,
                ManualValues = rand.Next(0, 1000) % 2 == 0,
                TemperatureUnit = rand.Next(100) % 2 == 0 ? "C" : "F",
                ChangeTemp_Per5Deg = (short)rand.Next(0, 1000),
                ChangeHumidity_Per5Precent = (short)rand.Next(0, 1000),
                HottestMonthTemp = (short)rand.Next(0, 1000),
                NormalHumidity = (short)rand.Next(0, 1000),
                PreciptationTreshold = (short)rand.Next(0, 1000)
            };

            return algorithm_P1;
        }

        #endregion

        #region Init & Clean

        private Models.AccountUser _user;

        [TestInitialize]
        public void Init()
        {
            _user = GeneralHelper.CreateTesterUser();

            using (var folderingConnector = new Foldering.TSQL.TSQLFolderingRepository())
            {
                _SiteID = folderingConnector.AddProject(new Models.MainSite()
                {
                    Name = $"testSite{rand.Next()}"
                }, _user.UserID);
            }

            _SN = "DEBUG" + ($"0{rand.Next(1, 99999)}".PadLeft(11, '0'));

            using (var deviceConnector = new Device.TSQL.TSQLDeviceRepository())
            {
                var types = deviceConnector.GetDeviceTypes();

                Assert.IsTrue(types != null && types.Length > 0);

                _DeviceID = deviceConnector.CreateDevice(_SN, "Test Device", null, 0, "", "", types[0].TypeID);
            }
        }

        [TestCleanup]
        public void Cleanup()
        {
            if (_SiteID != -1)
            {
                using (var folderingConnector = new Foldering.TSQL.TSQLFolderingRepository())
                {
                    folderingConnector.DeleteSite(_SiteID, _user.UserID);
                }
                _SiteID = -1;
            }


            if (_user != null)
            {
                using (var accountConnector = new Account.TSQL.TSQLAccountRepository())
                {
                    accountConnector.DeleteUser(_user.UserID);
                }
                _user = null;
            }

            if (_DeviceID != -1)
            {
                using (var deviceConnector = new Device.TSQL.TSQLDeviceRepository())
                {
                    deviceConnector.DeleteDevice(_SN, _DeviceID);
                }

                _SN = "";
                _DeviceID = -1;
            }
        }

        #endregion

        [TestMethod()]
        public void WeatherAlgorithm_P1_AllTests_Test()
        {
            var connector = _CreateConnector();

            //add new algorithm P1 ---------------------------------------------------
            var algorithm_P1 = _Create_RandomAlgorithm_P1();

            Assert.IsTrue(connector.WeatherAlgorithm_P1_Add(algorithm_P1));
            Assert.AreNotEqual(0, algorithm_P1.AlgorithmID);


            //get algorithm P1 ---------------------------------------------------
            var algorithm_back = connector.WeatherAlgorithm_P1_Get(algorithm_P1.AlgorithmID);
            CompareAlgorithm_P1(algorithm_P1, algorithm_back);


            //update algorithm P1 ---------------------------------------------------
            for (int i = 0; i < 10; i++)
            {
                //update
                var algorithm_P1_updated = _Create_RandomAlgorithm_P1();
                algorithm_P1_updated.IsEnabled = i % 2 == 0;
                algorithm_P1_updated.AlgorithmID = algorithm_P1.AlgorithmID;
                Assert.IsTrue(connector.WeatherAlgorithm_P1_Update(algorithm_P1_updated));

                //get algorithm P1 ---------------------------------------------------
                var algorithm_back2 = connector.WeatherAlgorithm_P1_Get(algorithm_P1.AlgorithmID);
                CompareAlgorithm_P1(algorithm_P1_updated, algorithm_back2);
            }

            //delete algorithm P1 ---------------------------------------------------
            Assert.IsTrue(connector.WeatherAlgorithm_P1_Delete(algorithm_P1.AlgorithmID));
            Assert.IsNull(connector.WeatherAlgorithm_P1_Get(algorithm_P1.AlgorithmID));
        }

        [TestMethod()]
        public void WeatherAlgorithm_P1_Get_Test()
        {
            //covered by WeatherAlgorithm_P1_AllTests_Test
        }
        [TestMethod()]
        public void WeatherAlgorithm_P1_Add_Test()
        {
            //covered by WeatherAlgorithm_P1_AllTests_Test
        }
        [TestMethod()]
        public void WeatherAlgorithm_P1_Update_Test()
        {
            //covered by WeatherAlgorithm_P1_AllTests_Test
        }
        [TestMethod()]
        public void WeatherAlgorithm_P1_Delete_Test()
        {
            //covered by WeatherAlgorithm_P1_AllTests_Test
        }


        [TestMethod()]
        public void WeatherAlgorithm_Site_AllTests_Test()
        {
            var connector = _CreateConnector();

            //null on beginning
            Assert.IsNull(connector.WeatherAlgorithm_Get(_SiteID));
            using (var folderingRep = new Foldering.TSQL.TSQLFolderingRepository())
            {
                var site = folderingRep.GetSite(_SiteID);
                Assert.IsNull(site.WeatherAlgorithmID);
            }

            //add new algorithm P1
            var algorithm_P1 = _Create_RandomAlgorithm_P1();
            Assert.IsTrue(connector.WeatherAlgorithm_P1_Add(algorithm_P1));

            //update in site
            Assert.IsTrue(connector.WeatherAlgorithm_UpdateSite(false, _user.UserID, _SiteID, algorithm_P1.AlgorithmID));


            //test is back for this site
            var site_algorithm_back1 = connector.WeatherAlgorithm_Get(_SiteID);
            Assert.IsNotNull(site_algorithm_back1);
            Assert.AreEqual(algorithm_P1.AlgorithmID, site_algorithm_back1.WeatherAlgorithmID);
            Assert.AreEqual(algorithm_P1.AlgorithmID, site_algorithm_back1.WeatherAlgorithmID);
            Assert.AreEqual(algorithm_P1.AlgorithmTypeID, site_algorithm_back1.WeatherAlgorithmTypeID);

            using (var folderingRep = new Foldering.TSQL.TSQLFolderingRepository())
            {
                var site = folderingRep.GetSite(_SiteID);
                Assert.IsNotNull(site.WeatherAlgorithmID);
                Assert.AreEqual(site_algorithm_back1.WeatherAlgorithmID, site.WeatherAlgorithmID);
            }

            Assert.IsTrue(connector.WeatherAlgorithm_P1_Delete(algorithm_P1.AlgorithmID));
            using (var folderingRep = new Foldering.TSQL.TSQLFolderingRepository())
            {
                var site = folderingRep.GetSite(_SiteID);
                Assert.IsNull(site.WeatherAlgorithmID);
            }
        }

        [TestMethod()]
        public void WeatherAlgorithm_UpdateSite_Test()
        {
            //covered by WeatherAlgorithm_Site_AllTests_Test
        }

        [TestMethod()]
        public void WeatherAlgorithm_Get_Site_Test()
        {
            //covered by WeatherAlgorithm_Site_AllTests_Test
        }

        [TestMethod()]
        public void WeatherAlgorithm_Device_AllTests_Test()
        {
            var connector = _CreateConnector();

            //null on beginning
            Assert.IsNull(connector.WeatherAlgorithm_Get(this._SN));
            using (var deviceRep = new Device.TSQL.TSQLDeviceRepository())
            {
                var device = deviceRep.GetDevice(_SN);
                Assert.IsNull(device.WeatherAlgorithmID);
                Assert.IsNull(device.WeatherAlgorithmBySiteID);
            }

            //////------------------------Algorithm P1 testing on site------------------------
            //add new algorithm P1
            var algorithm_P1 = _Create_RandomAlgorithm_P1();
            Assert.IsTrue(connector.WeatherAlgorithm_P1_Add(algorithm_P1));

            //update in site
            Assert.IsTrue(connector.WeatherAlgorithm_Update(_SN, algorithm_P1.AlgorithmID));

            //test is back for this site
            var site_algorithm_back1 = connector.WeatherAlgorithm_Get(_SN);
            Assert.IsNotNull(site_algorithm_back1);
            Assert.AreEqual(algorithm_P1.AlgorithmID, site_algorithm_back1.WeatherAlgorithmID);
            Assert.AreEqual(algorithm_P1.AlgorithmID, site_algorithm_back1.WeatherAlgorithmID);
            Assert.AreEqual(algorithm_P1.AlgorithmTypeID, site_algorithm_back1.WeatherAlgorithmTypeID);

            using (var deviceRep = new Device.TSQL.TSQLDeviceRepository())
            {
                var device = deviceRep.GetDevice(_SN);
                Assert.IsNotNull(device.WeatherAlgorithmID);
                Assert.IsNull(device.WeatherAlgorithmBySiteID);
                Assert.AreEqual(site_algorithm_back1.WeatherAlgorithmID, device.WeatherAlgorithmID);
            }

            Assert.IsTrue(connector.WeatherAlgorithm_P1_Delete(algorithm_P1.AlgorithmID));
            var site_algorithm_back2 = connector.WeatherAlgorithm_Get(_SN);
            Assert.IsNull(site_algorithm_back2);

            using (var deviceRep = new Device.TSQL.TSQLDeviceRepository())
            {
                var device = deviceRep.GetDevice(_SN);
                Assert.IsNull(device.WeatherAlgorithmID);
                Assert.IsNull(device.WeatherAlgorithmBySiteID);
            }
        }

        [TestMethod()]
        public void WeatherAlgorithm_Get_Device_Test()
        {
            //covered by WeatherAlgorithm_Device_AllTests_Test
        }

        [TestMethod()]
        public void WeatherAlgorithm_Update_Device_Test()
        {
            //covered by WeatherAlgorithm_Device_AllTests_Test
        }
    }
}