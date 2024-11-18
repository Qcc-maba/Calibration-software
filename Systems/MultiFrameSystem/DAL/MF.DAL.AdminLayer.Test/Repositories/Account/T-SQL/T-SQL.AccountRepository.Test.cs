using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories.Account.TSQL;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories.Account.TSQL.Test
{
    [TestClass]
    public class MF_AdminLayer_Account__TSQLAccountRepository_Test
    {
        private TSQLAccountRepository rep = null;
        private Models.AccountUser _user = null;
        private Random rand = new Random();
        private Models.GlobalizationZone[] _GlobalizationZones = null;


        #region ctor

        public MF_AdminLayer_Account__TSQLAccountRepository_Test()
        {
            rep = new TSQLAccountRepository();

            _GlobalizationZones = rep.GetGlobalizationZones(null);
        }

        #endregion

        #region Init & Clean

        [TestInitialize]
        public void Init()
        {
            GeneralHelper.Init();

            _user = GeneralHelper.CreateTesterUser();
        }

        [TestCleanup]
        public void Clean()
        {
            GeneralHelper.Clean();
        }

        #endregion

        #region Tests

        [TestMethod]
        public void RefreshUserExhange_Test()
        {
            var _testedUser = GeneralHelper.CreateTesterUser();

            //empty user
            var exchangeData = rep.GetExchange_ByEmail(_testedUser.Email);
            Assert.IsNotNull(exchangeData);
            Assert.AreEqual(_testedUser.UserID, exchangeData.UserID);
            Assert.AreEqual(0, exchangeData.DeviceCount);
            Assert.AreEqual(0, exchangeData.RootSiteCount);
            Assert.AreEqual(0, exchangeData.SiteTotalCount);
            Assert.IsNull(exchangeData.Entry_ProjectID);
            Assert.IsNull(exchangeData.Entry_SiteID);
            Assert.IsNull(exchangeData.Entry_SN);

            //add project and check
            var folderingRepository = new Foldering.TSQL.TSQLFolderingRepository();
            long NewProjectID = folderingRepository.AddProject(new Models.MainSite() { Name = "tets" }, _testedUser.UserID);
            Assert.AreNotEqual(0, NewProjectID);

            //refresh
            rep.RefreshUserExhange(_testedUser.UserID);

            exchangeData = rep.GetExchange_ByEmail(_testedUser.Email);
            Assert.IsNotNull(exchangeData);
            Assert.AreEqual(_testedUser.UserID, exchangeData.UserID);
            Assert.AreEqual(0, exchangeData.DeviceCount);
            Assert.AreEqual(1, exchangeData.RootSiteCount);
            Assert.AreEqual(0, exchangeData.SiteTotalCount);
            Assert.AreEqual(NewProjectID, exchangeData.Entry_ProjectID);
            Assert.IsNull(exchangeData.Entry_SiteID);
            Assert.IsNull(exchangeData.Entry_SN);

            //add site and check
            long NewSiteID = folderingRepository.AddSite(_testedUser.UserID, new Models.MainSite() { Name = "tets", ParentSiteID = NewProjectID });
            Assert.AreNotEqual(0, NewSiteID);

            //refresh
            rep.RefreshUserExhange(_testedUser.UserID);

            exchangeData = rep.GetExchange_ByEmail(_testedUser.Email);
            Assert.IsNotNull(exchangeData);
            Assert.AreEqual(_testedUser.UserID, exchangeData.UserID);
            Assert.AreEqual(0, exchangeData.DeviceCount);
            Assert.AreEqual(1, exchangeData.RootSiteCount);
            Assert.AreEqual(1, exchangeData.SiteTotalCount);
            Assert.AreEqual(NewProjectID, exchangeData.Entry_ProjectID);
            Assert.AreEqual(NewSiteID, exchangeData.Entry_SiteID);
            Assert.IsNull(exchangeData.Entry_SN);
        }

        [TestMethod]
        public void UpdateMessagesCount_Test()
        {
            int diff = 50;
            for (int i = 0; i < 2; i++)
            {

                var before = rep.CountUserMessages(_user.Email);
                Assert.IsTrue(rep.UpdateMessagesCount(_user.Email, diff));
                var after = rep.CountUserMessages(_user.Email);
                Assert.AreEqual(after - before, diff);

                diff = diff * -1;
            }
        }

        [TestMethod()]
        public void ResetMessagesCount_Test()
        {
            var before = rep.CountUserMessages(_user.Email);
            if (before == 0)
            {
                Assert.IsTrue(rep.UpdateMessagesCount(_user.Email, 5));
            }
            //make sure it's not 0
            Assert.IsTrue(rep.CountUserMessages(_user.Email) > 0);

            Assert.IsTrue(rep.ResetMessagesCount(_user.UserID));

            //make sure it's reset
            var after = rep.CountUserMessages(_user.Email);
            Assert.AreEqual(after, 0);
        }

        [TestMethod()]
        public void CountUserMessages_Test()
        {
            //covered be UpdateMessagesCount_Test
            Assert.IsTrue(true);
        }

        [TestMethod()]
        public void GetUser_Test()
        {
            var user = rep.GetUser(_user.UserID);

            Assert.AreEqual(_user.UserID, user.UserID);

            Assert.AreEqual(_user.FirstName, user.FirstName);
            Assert.AreEqual(_user.LastName, user.LastName);
            Assert.AreEqual(_user.ImgURL, user.ImgURL);
            Assert.AreEqual(_user.Email, user.Email);
            Assert.AreEqual(_user.CultureCode, user.CultureCode);
        }

        [TestMethod()]
        public void GetExchange_Test()
        {
            var exchange = rep.GetExchange(_user.UserID);
            Assert.IsNotNull(exchange);
        }

        [TestMethod()]
        public void GetExchange_ByGUID_Test()
        {
            var exchange = rep.GetExchange_ByGUID(_user.IdentityUserGUID);
            Assert.IsNotNull(exchange);
        }

        [TestMethod()]
        public void GetExchange_ByEmail_Test()
        {
            var exchange = rep.GetExchange_ByEmail(_user.Email);
            Assert.IsNotNull(exchange);
        }

        [TestMethod()]
        public void AddUser_Test()
        {
            var _testedUser = GeneralHelper.CreateTesterUser();

            //add the user
            Assert.IsNotNull(_testedUser);

            #region get user by id

            var user2 = rep.GetUser(_testedUser.UserID);
            _testedUser.TimeZoneID = user2.TimeZoneID;

            Assert.AreEqual(_testedUser.UserID, user2.UserID);

            Assert.AreEqual(_testedUser.FirstName, user2.FirstName);
            Assert.AreEqual(_testedUser.LastName, user2.LastName);
            Assert.AreEqual(_testedUser.ImgURL, user2.ImgURL);
            Assert.AreEqual(_testedUser.Email, user2.Email);
            Assert.AreEqual(_testedUser.CultureCode, user2.CultureCode);

            #endregion

            //by email

            #region get user by email

            var user3 = rep.GetUser(_testedUser.Email);
            Assert.AreEqual(_testedUser.UserID, user3.UserID);

            Assert.AreEqual(_testedUser.FirstName, user3.FirstName);
            Assert.AreEqual(_testedUser.LastName, user3.LastName);
            Assert.AreEqual(_testedUser.ImgURL, user3.ImgURL);
            Assert.AreEqual(_testedUser.Email, user3.Email);
            Assert.AreEqual(_testedUser.CultureCode, user3.CultureCode);
            Assert.AreEqual(_testedUser.TimeZoneID, user3.TimeZoneID);

            #endregion
        }

        [TestMethod()]
        public void DeleteUser_Test()
        {
            var _testedUser = GeneralHelper.CreateTesterUser();
            Assert.IsNotNull(_testedUser);

            Assert.IsTrue(rep.DeleteUser(_testedUser.UserID));

            var tested2 = rep.GetUser(_testedUser.UserID);

            Assert.IsNull(tested2);
        }

        [TestMethod()]
        public void UpdateUser_Test()
        {
            var _testedUser = GeneralHelper.CreateTesterUser();

            _testedUser.FirstName = $"FirstName_{rand.Next(1, 10000)}";
            _testedUser.LastName = $"LastName_changed2{rand.Next(1, 10000)}";
            _testedUser.ImgURL = $"ImgURL_changed2{rand.Next(1, 10000)}";
            _testedUser.TimeZoneID = _GlobalizationZones[rand.Next(0, _GlobalizationZones.Length - 1)].ZoneID;
            _testedUser.CultureCode = $"xx{rand.Next(1, 10)}";
            _testedUser.Version++;

            Assert.IsTrue(rep.UpdateUser(_testedUser));

            //get another copy to compare after update
            var user4 = rep.GetUser(_testedUser.UserID);
            Assert.AreEqual(_testedUser.UserID, user4.UserID);

            Assert.AreEqual(_testedUser.FirstName, user4.FirstName);
            Assert.AreEqual(_testedUser.LastName, user4.LastName);
            Assert.AreEqual(_testedUser.ImgURL, user4.ImgURL);
            Assert.AreEqual(_testedUser.Email, user4.Email);
            Assert.AreEqual(_testedUser.TimeZoneID, user4.TimeZoneID);
            Assert.AreEqual(_testedUser.CultureCode, user4.CultureCode);
        }

        [TestMethod()]
        public void GetGlobalizationZones_Test()
        {
            var zones = rep.GetGlobalizationZones(null);
            Assert.IsNotNull(zones);
            Assert.IsTrue(zones.Length > 0);

            //test filter version
            for (int i = 0; i < 3; i++)
            {
                int z = rand.Next(0, zones.Length - 1);
                var GMTOffset = zones[z].GMTOffset;
                var zone_filter = rep.GetGlobalizationZones(GMTOffset);
                Assert.IsTrue(zone_filter.Length > 0);
                Assert.IsTrue(zone_filter.All(zone => zone.GMTOffset == GMTOffset));
            }
        }

        #endregion
    }
}
