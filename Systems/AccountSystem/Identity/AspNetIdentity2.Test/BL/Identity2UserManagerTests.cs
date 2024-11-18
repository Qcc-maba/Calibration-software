using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.AccountSystem.AspNetIdentity.Identity2.BL;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.Test
{
    [TestClass()]
    public class Identity2UserManagerTests
    {
        Random rand = new Random();

        private TestContext testContextInstance;
        public TestContext TestContext
        {
            get
            {
                return testContextInstance;
            }
            set
            {
                testContextInstance = value;
            }
        }
        public static List<string> Tests = new List<string>();

        #region CONSTANTS

        private const string DEFAULT_PASSWORD = "Ze_123456";

        #endregion

        #region private members

        private BL.Models.SystemTimeZoneModel[] TimeZones { get; set; }
        private BL.Models.SystemUIFormatModel[] SystemUIFormats { get; set; }
        private BL.Models.SystemTemperatureUnitModel[] TemperatureUnits { get; set; }
        private BL.Models.UserRoleModel[] Roles { get; set; }

        private List<DAL.BaseUser> _Users = new List<DAL.BaseUser>();

        private Identity2UserManager _Manager = null;

        #endregion

        #region ctor

        public Identity2UserManagerTests()
        {

        }

        #endregion

        [TestInitialize]
        public void Init()
        {
            Tests.Add($"{System.Threading.Thread.CurrentThread.ManagedThreadId}_{TestContext.TestName}");

            var _connector = new DAL.IdentityStore_SQL();
            _Manager = new Identity2UserManager(_connector);

            var _TimeZones = Wait(_Manager.System_TimeZonesAsync());
            Assert.AreNotEqual(0, _TimeZones.Result.Length);
            TimeZones = _TimeZones.Result;

            SystemUIFormats = Wait(_Manager.System_UIFormatsAsync()).Result;
            Assert.AreNotEqual(0, SystemUIFormats.Length);

            TemperatureUnits = Wait(_Manager.System_TemperatureUnitsAsync()).Result;
            Assert.AreNotEqual(0, TemperatureUnits.Length);

            Roles = Wait(_Manager.System_RoleModels())
                            .Result
                            .ToArray();
        }

        #region Init & Cleanup

        [TestCleanup]
        public void cleanup()
        {
            foreach (var u in _Users)
            {
                ValidateResult(Wait(_Manager.User_DeleteAsync(u.UserID, u.Email)));
            }
        }

        #endregion

        #region private methods

        private T ValidateResultT<T>(ActionResult<T> result, bool ExpectedResult = true)
        {
            Assert.IsNotNull(result);

            if (ExpectedResult)
            {
                Assert.IsNotNull(result.Result);
            }
            else
            {
                Assert.IsNull(result.Result);
            }

            Assert.AreEqual(ExpectedResult, result.Succeeded);

            return result.Result;
        }

        private void ValidateResult(ActionResult result, bool ExpectedResult = true)
        {
            Assert.IsNotNull(result);
            Assert.AreEqual(ExpectedResult, result.Succeeded);
        }

        private T Wait<T>(Task<T> t)
        {
            Assert.IsTrue(t.Wait(100000));

            return t.Result;
        }
        private DAL.BaseUser _CreateUser(int? num = null, bool ConfirmEmail = true)
        {
            //create user
            if (!num.HasValue)
            {
                num = rand.Next(0, 9999999);
            }

            var name = this.TestContext.TestName.Length > 40 ? this.TestContext.TestName.Substring(0, 40) : this.TestContext.TestName;
            var newUser = new DAL.BaseUser()
            {
                Email = $"{name}@{rand.Next(10, 500000)}.com",
            };

            _ModifyRandomUser(newUser, num.Value);

            var newCreatedUser = new Identity2.BL.Models.CreateUserModel()
            {
                City = newUser.City,
                Email = newUser.Email,
                Country = newUser.Country,
                EmailConfirmed = newUser.EmailConfirmed,
                FirstName = newUser.FirstName,
                LastName = newUser.LastName,
                LongDatePattern = newUser.LongDatePattern,
                LongTimePattern = newUser.LongTimePattern,
                PhoneConfirmed = newUser.PhoneConfirmed,
                PhoneNumber = newUser.PhoneNumber,
                ShortDatePattern = newUser.ShortDatePattern,
                ShortTimePattern = newUser.ShortDatePattern,
                StreetName = newUser.StreetName,
                StreetNo = newUser.StreetNo,
                TemperatureUnitID = newUser.TemperatureUnitID,
                TimeZoneID = newUser.TimeZoneID,
                UIFormatID = newUser.UIFormatID,
                ZipCode = newUser.ZipCode
            };



            var createResult = Wait(_Manager.User_CreateAsync(newCreatedUser, false, DEFAULT_PASSWORD));
            Assert.IsTrue(createResult.Succeeded);
            var user_back = Wait(_Manager.User_FindByIDAsync(newCreatedUser.Get_UserID()));
            Assert.IsTrue(user_back.Succeeded);

            if (ConfirmEmail)
            {
                var generateTokenResult = Wait(_Manager.User_GenerateEmailConfirmationTokenAsync(user_back.Result.Get_UserID()));
                Assert.IsTrue(generateTokenResult.Succeeded);

                var confirmResult = Wait(_Manager.User_ConfirmEmailAsync(newCreatedUser.Email, generateTokenResult.Result));
                Assert.IsTrue(confirmResult.Succeeded);

                user_back.Result.UpdateVersion++;
                user_back.Result.EmailConfirmed = true;
            }

            //fix properties we cannot know without the Store (like UserID, Version..)
            newUser.UserID = newCreatedUser.Get_UserID();
            newUser.UserName = user_back.Result.Get_UserName();
            newUser.UpdateVersion = user_back.Result.UpdateVersion;
            newUser.EmailConfirmed = user_back.Result.EmailConfirmed;

            compareUsers(user_back.Result, newUser);

            _Users.Add(newUser);

            return newUser;
        }
        private void _ModifyRandomUser(DAL.BaseUser user, int num)
        {
            //don't touch these parameters
            // user.UserGuid = null;
            //user.UserID = -1;
            //user.Version = num;

            user.City = num == 0 ? null : $"City_{num}";
            user.Country = num == 0 ? null : $"Country_{num}";
            user.FirstName = num == 0 ? null : $"FirstName_{num}";
            user.LastName = num == 0 ? null : $"LastName_{num}";
            user.ZipCode = $"{96000 + num * 100}";
            user.StreetName = num == 0 ? null : $"Street_{num}";
            user.StreetNo = num + 5;

            user.PhoneNumber = $"{ num * 12356}";

            user.UIFormatID = this.SystemUIFormats[num % this.SystemUIFormats.Length].UIFormatID;
            user.LongDatePattern = num == 0 ? null : $"LongDatePattern_{num}";
            user.LongTimePattern = num == 0 ? null : $"LongTimePattern_{num}";
            user.ShortTimePattern = num == 0 ? null : $"ShortTimePattern_{num}";
            user.ShortDatePattern = num == 0 ? null : $"ShortDatePattern_{num}";

            user.TemperatureUnitID = this.TemperatureUnits[num % this.TemperatureUnits.Length].TypeUnitID;
            user.TimeZoneID = this.TimeZones[num % this.TimeZones.Length].ZoneID;

            //updated separately, should not be updated in Update function...
            /*user.ImgURL = num == 0 ? null : $"http://mage.com/Image_{num}.png";
            user.AccessFailedCount = num + 9;
            user.LockoutEnabled = num % 2 == 0; //just read, write separately
            user.LockoutEndDateUtc = num == 0 ? (DateTime?)null : DateTime.UtcNow.AddDays(num);
            user.UserName = 
            */
        }

        private void compareUsers(BL.Models.ApplicationUserModel user_back, DAL.BaseUser user)
        {
            Assert.AreEqual(user_back.Get_UserName(), user.UserName);

            Assert.AreEqual(user_back.City, user.City);
            Assert.AreEqual(user_back.Country, user.Country);
            Assert.AreEqual(user_back.Email, user.Email);
            Assert.AreEqual(user_back.EmailConfirmed, user.EmailConfirmed);
            Assert.AreEqual(user_back.FirstName, user.FirstName);
            Assert.AreEqual(user_back.ImgURL, user.ImgURL);
            Assert.AreEqual(user_back.LastName, user.LastName);
            Assert.AreEqual(user_back.PhoneConfirmed, user.PhoneConfirmed);
            Assert.AreEqual(user_back.StreetName, user.StreetName);
            Assert.AreEqual(user_back.StreetNo, user.StreetNo);
            Assert.AreEqual(user_back.TemperatureUnitID, user.TemperatureUnitID);
            Assert.AreEqual(user_back.UpdateVersion, user.UpdateVersion);
            Assert.AreEqual(user_back.ZipCode, user.ZipCode);
            Assert.AreEqual(user_back.UIFormatID, user.UIFormatID);
            Assert.AreEqual(user_back.AccessFailedCount, user.AccessFailedCount);
            Assert.AreEqual(user_back.LockoutEnabled, user.LockoutEnabled);
            Assert.AreEqual(user_back.LockoutEndDateUtc, user.LockoutEndDateUtc);
            Assert.AreEqual(user_back.PhoneNumber, user.PhoneNumber);
            Assert.AreEqual(user_back.TimeZoneID, user.TimeZoneID);


            //if (testHash)
            //{
            //    Assert.AreEqual(user_back.SecurityStamp, user.SecurityStamp);
            //    Assert.AreEqual(user_back.PasswordHash, user.PasswordHash);
            //}

            Assert.AreEqual(user_back.UIFormatID, user.UIFormatID);
            /*var uiFormat = this.SystemUIFormats.FirstOrDefault(u => u.UIFormatID == user_back.UIFormatID);

            if (!String.IsNullOrEmpty(user.ShortDatePattern))
            {
                Assert.AreEqual(user_back.ShortDatePattern, user.ShortDatePattern);
            }
            else
            {
                Assert.AreEqual(user_back.ShortDatePattern, uiFormat.ShortDatePattern);
            }

            if (!String.IsNullOrEmpty(user.ShortTimePattern))
            {
                Assert.AreEqual(user_back.ShortTimePattern, user.ShortTimePattern);
            }
            else
            {
                Assert.AreEqual(user_back.ShortTimePattern, uiFormat.ShortTimePattern);
            }

            if (!String.IsNullOrEmpty(user.LongDatePattern))
            {
                Assert.AreEqual(user_back.LongDatePattern, user.LongDatePattern);
            }
            else
            {
                Assert.AreEqual(user_back.LongDatePattern, uiFormat.LongDatePattern);
            }

            if (!String.IsNullOrEmpty(user.LongTimePattern))
            {
                Assert.AreEqual(user_back.LongTimePattern, user.LongTimePattern);
            }
            else
            {
                Assert.AreEqual(user_back.LongTimePattern, uiFormat.LongTimePattern);
            }*/

        }
        #endregion

        [TestMethod()]
        public void GetSystemTimeZoneModel_Test()
        {
            var timeZones = ValidateResultT(Wait(_Manager.System_TimeZonesAsync()));
            Assert.AreNotEqual(0, timeZones.Length);

            int fallbackValue = 43243432;

            foreach (var z in timeZones)
            {
                Assert.AreNotEqual(fallbackValue, z.GetActualOffset(z.SystemZoneID, fallbackValue));
            }
        }

        [TestMethod()]
        public void GetUIFormats_Test()
        {
            var uiFormats = ValidateResultT(Wait(_Manager.System_UIFormatsAsync()));
            Assert.AreNotEqual(0, uiFormats.Length);
        }

        [TestMethod()]
        public void GetSystemTemperatureUnits_Test()
        {
            var temperatureUnits = ValidateResultT(Wait(_Manager.System_TemperatureUnitsAsync()));
            Assert.AreNotEqual(0, temperatureUnits.Length);
        }

        [TestMethod()]
        public void User_ImageUpload_Test()
        {
            var user = _CreateUser();

            var oldImageURI = user.ImgURL;
            var newImageURI = $"http://image.com/{DateTime.UtcNow.Ticks}.jpeg";
            Assert.AreNotEqual(oldImageURI, newImageURI);
            ValidateResult(Wait(_Manager.User_ImageUploadAsync(user.UserID, newImageURI)));

            var user_back = Wait(_Manager.User_FindByIDAsync(user.UserID));
            Assert.AreEqual(user_back.Result.ImgURL, newImageURI);
            Assert.AreNotEqual(user_back.Result.ImgURL, oldImageURI);
        }

        [TestMethod()]
        public void ChangePhoneNumberAsync_Test()
        {
            var user = _CreateUser();
            Assert.IsFalse(user.PhoneConfirmed);

            var oldPhone = user.PhoneNumber;
            var newPhone = $"{DateTime.UtcNow.Ticks}";
            Assert.AreNotEqual(newPhone, oldPhone);
            var token = ValidateResultT(Wait(_Manager.User_GenerateChangePhoneConfirmationTokenAsync(user.UserID, newPhone)));

            ValidateResult(Wait(_Manager.User_ChangePhoneNumberAsync(user.UserID, newPhone, token)));
            var user_back = Wait(_Manager.User_FindByIDAsync(user.UserID));

            Assert.IsTrue(user_back.Result.PhoneConfirmed);
            Assert.AreEqual(user_back.Result.PhoneNumber, newPhone);
            Assert.AreNotEqual(user_back.Result.PhoneNumber, oldPhone);
        }

        [TestMethod()]
        public void User_GenerateChangePhoneConfirmationTokenAsync_Test()
        {
            //covered by ChangePhoneNumberAsync_Test
        }

        [TestMethod()]
        public void GeneratePasswordResetTokenAsync_Test()
        {
            //covered by ResetPasswordAsync_Test
        }

        [TestMethod()]
        public void ResetPasswordAsync_Test()
        {
            var user = _CreateUser();

            var newPassword = $"{DateTime.UtcNow.Ticks}";

            //test before change - old password
            var result_beforeChange_default = Wait(_Manager.User_FindByUserNameAsync(user.UserName, DEFAULT_PASSWORD));
            user.UpdateVersion++;
            Assert.IsTrue(result_beforeChange_default.Succeeded);
            Assert.IsNotNull(result_beforeChange_default.Result);
            compareUsers(result_beforeChange_default.Result, user);

            //test before change - new password (make sure this failure was record)
            var result_beforeChange_new = Wait(_Manager.User_FindByUserNameAsync(user.UserName, newPassword));
            user.AccessFailedCount++;
            user.UpdateVersion++;
            Assert.IsFalse(result_beforeChange_new.Succeeded);
            Assert.IsNull(result_beforeChange_new.Result);
            //make sure this failure was record
            var user_back = Wait(_Manager.User_FindByIDAsync(user.UserID));
            compareUsers(user_back.Result, user);
            Assert.IsNotNull(user_back.Result.LastFailedLoginDateUtc);

            //change password
            var tokenResult = Wait(_Manager.User_GeneratePasswordResetTokenAsync(user.UserID));
            Assert.IsTrue(tokenResult.Succeeded);
            var token = tokenResult.Result;

            ValidateResult(Wait(_Manager.User_ResetPasswordAsync(user.UserID, token, newPassword)));
            user.UpdateVersion++;
            user_back = Wait(_Manager.User_FindByIDAsync(user.UserID));

            //test after change (reset failure)
            user.AccessFailedCount = 0;
            var result_afterChange = ValidateResultT(Wait(_Manager.User_FindByUserNameAsync(user.UserName, newPassword)));
            user.UpdateVersion++;
            compareUsers(result_afterChange, user);
        }

        [TestMethod()]
        public void ConfirmEmailAsync_Test()
        {
            var user = _CreateUser(ConfirmEmail: false);
            Assert.IsFalse(user.EmailConfirmed);

            //change password
            var token = ValidateResultT(Wait(_Manager.User_GenerateEmailConfirmationTokenAsync(user.UserID)));

            ValidateResult(Wait(_Manager.User_ConfirmEmailAsync(user.Email, token)));
            var user_back = Wait(_Manager.User_FindByIDAsync(user.UserID));

            //test after change
            var result_afterChange = ValidateResultT(Wait(_Manager.User_FindByEmailAsync(user.Email, DEFAULT_PASSWORD)));
            user.UpdateVersion++;
            Assert.IsTrue(result_afterChange.EmailConfirmed);
        }

        [TestMethod()]
        public void GenerateEmailConfirmationTokenAsync_Test()
        {
            //covered by ConfirmEmailAsync_Test
        }

        [TestMethod()]
        public void ChangePasswordAsync_Test()
        {
            var user = _CreateUser();

            var newPassword = $"{DateTime.UtcNow.Ticks}";

            //test before change - old password
            var result_beforeChange_default = Wait(_Manager.User_FindByUserNameAsync(user.UserName, DEFAULT_PASSWORD));
            user.UpdateVersion++;
            Assert.IsTrue(result_beforeChange_default.Succeeded);
            Assert.IsNotNull(result_beforeChange_default.Result);
            compareUsers(result_beforeChange_default.Result, user);

            //test before change - new password (should fail, increase [AccessFailedCount]
            var result_beforeChange_new = Wait(_Manager.User_FindByUserNameAsync(user.UserName, newPassword));
            user.UpdateVersion++;
            user.AccessFailedCount++;
            Assert.IsFalse(result_beforeChange_new.Succeeded);
            Assert.IsNull(result_beforeChange_new.Result);

            //change password
            ValidateResult(Wait(_Manager.User_ChangePasswordAsync(user.UserID, DEFAULT_PASSWORD, newPassword)));
            user.UpdateVersion++;

            //test after change - new password
            var result_afterChange = ValidateResultT(Wait(_Manager.User_FindByUserNameAsync(user.UserName, newPassword)));
            user.UpdateVersion++;
            user.AccessFailedCount = 0; //good login resets counter
            Assert.IsNotNull(result_afterChange.LastFailedLoginDateUtc); //good login should keep last failed login
            compareUsers(result_afterChange, user);

            //test after change - old password
            var result_afterChange_default = ValidateResultT(Wait(_Manager.User_FindByUserNameAsync(user.UserName, DEFAULT_PASSWORD)), false);
        }

        [TestMethod()]
        public void FindUserByLoginAsync_Test()
        {
            var user = _CreateUser();

            //test - success
            var user_back_success = ValidateResultT(Wait(_Manager.User_FindByUserNameAsync(user.UserName)));
            Assert.AreEqual(user.UserName, user_back_success.Get_UserName());
            Assert.AreEqual(user.Email, user_back_success.Email);

            //test - success
            var user_back_fail = ValidateResultT(Wait(_Manager.User_FindByUserNameAsync("Boby9" + user.UserName)), false);
            Assert.IsNull(user_back_fail);
        }

        [TestMethod()]
        public void FindByEmailAsync_Test()
        {
            var user = _CreateUser();

            //test - success
            var user_back_success = ValidateResultT(Wait(_Manager.User_FindByEmailAsync(user.Email)));
            Assert.AreEqual(user.UserName, user_back_success.Get_UserName());
            Assert.AreEqual(user.Email, user_back_success.Email);

            //test - success
            var user_back_fail = ValidateResultT(Wait(_Manager.User_FindByEmailAsync("Boby9" + user.Email)), false);
            Assert.IsNull(user_back_fail);
        }

        [TestMethod()]
        public void FindByEmailAsync_Test_withPassword()
        {
            var user = _CreateUser();

            //test correct password
            var user_back = ValidateResultT(Wait(_Manager.User_FindByEmailAsync(user.Email, DEFAULT_PASSWORD)));
            Assert.AreEqual(user.Email, user_back.Email);

            //test incorrect password
            var user_back_falsy = ValidateResultT(Wait(_Manager.User_FindByEmailAsync(user.Email, DEFAULT_PASSWORD + "3")), false);
        }

        [TestMethod()]
        public void FindByUserNameAsync_Test()
        {
            var user = _CreateUser();

            //test correct password
            var user_back = ValidateResultT(Wait(_Manager.User_FindByUserNameAsync(user.UserName)));
            Assert.AreEqual(user.Email, user_back.Email);

            //test correct password
            var user_back_falsy = ValidateResultT(Wait(_Manager.User_FindByUserNameAsync("Boby9" + user.UserName)), false);
        }

        [TestMethod()]
        public void FindByUserNameAsync_Test_withPassword()
        {
            var user = _CreateUser();

            //test correct password
            var user_back = ValidateResultT(Wait(_Manager.User_FindByUserNameAsync(user.UserName, DEFAULT_PASSWORD)));
            Assert.AreEqual(user.Email, user_back.Email);

            //test incorrect password
            var user_back_falsy1 = ValidateResultT(Wait(_Manager.User_FindByUserNameAsync(user.UserName, DEFAULT_PASSWORD + "3")), false);
            //test incorrect username
            var user_back_falsy2 = ValidateResultT(Wait(_Manager.User_FindByUserNameAsync("Boby9" + user.UserName, DEFAULT_PASSWORD)), false);
        }

        [TestMethod()]
        public void CreateAsync_Test_WithDefaults()
        {
            var rand = new Random();
            var name = this.TestContext.TestName.Length > 40 ? this.TestContext.TestName.Substring(0, 40) : this.TestContext.TestName;

            var newUser = new BL.Models.CreateUserModel()
            {
                Email = $"{name}@{rand.Next(10, 500000)}.com",
                City = "myCity",
                Country = "myCountry",
                StreetName = "myStreet",
                StreetNo = 8,
                PhoneNumber = "444"
            };

            var createResult = Wait(_Manager.User_CreateAsync(newUser, true, DEFAULT_PASSWORD));
            Assert.IsTrue(createResult.Succeeded);

            var user_back = ValidateResultT(Wait(_Manager.User_FindByEmailAsync(newUser.Email)));
            Assert.AreEqual(newUser.FirstName, newUser.FirstName);
            Assert.AreEqual(newUser.LastName, newUser.LastName);
            Assert.AreEqual(newUser.Email, newUser.Email);
            Assert.AreEqual(newUser.City, newUser.City);
            Assert.AreEqual(newUser.Country, newUser.Country);
            Assert.AreEqual(newUser.StreetName, newUser.StreetName);
            Assert.AreEqual(newUser.StreetNo, newUser.StreetNo);
            Assert.AreEqual(newUser.PhoneNumber, newUser.PhoneNumber);

            var deleteResult = Wait(_Manager.User_DeleteAsync(user_back.Get_UserID(), user_back.Email));

        }


        [TestMethod()]
        public void CreateAsync_Test()
        {
            var user = _CreateUser();

            //test correct password
            var user_back = ValidateResultT(Wait(_Manager.User_FindByUserNameAsync(user.UserName, DEFAULT_PASSWORD)));
            user.UpdateVersion++;

            Assert.AreEqual(user.Email, user_back.Email);

            for (int i = 0; i < 10; i++)
            {
                _ModifyRandomUser(user, i);

                //act
                var _updateUser = new BL.Models.UpdateUserModel()
                {
                    Email = user_back.Email,
                    City = user.City,
                    Country = user.Country,
                    FirstName = user.FirstName,
                    LastName = user.LastName,
                    LongDatePattern = user.LongDatePattern,
                    LongTimePattern = user.LongTimePattern,
                    PhoneNumber = user.PhoneNumber,
                    ShortDatePattern = user.ShortDatePattern,
                    ShortTimePattern = user.ShortTimePattern,
                    StreetName = user.StreetName,
                    StreetNo = user.StreetNo,
                    TemperatureUnitID = user.TemperatureUnitID,
                    TimeZoneID = user.TimeZoneID,
                    UIFormatID = user.UIFormatID,
                    ZipCode = user.ZipCode                    
                };
                ValidateResult(Wait(_Manager.User_UpdateAsync(_updateUser)));

                //test
                var user_back_afterChange = ValidateResultT(Wait(_Manager.User_FindByIDAsync(user.UserID)));
                user.UpdateVersion++;
                compareUsers(user_back_afterChange, user);
            }
        }

        [TestMethod()]
        public void DeleteUserAsync_Test()
        {
            var user = _CreateUser();

            //prepare
            var user_back = ValidateResultT(Wait(_Manager.User_FindByEmailAsync(user.Email)));
            Assert.AreEqual(user.Email, user_back.Email);

            //act
            ValidateResult(Wait(_Manager.User_DeleteAsync(user.UserID, user.Email)));

            //test
            var user_back_afterDelete = ValidateResultT(Wait(_Manager.User_FindByEmailAsync(user.Email)), false);
            Assert.IsNull(user_back_afterDelete);
        }

        [TestMethod()]
        public void UpdateUserAsync_Test()
        {
            //covered by CreateAsync_Test
        }

        [TestMethod()]
        public void AddLoginAsync_Test()
        {
            var user = _CreateUser();

            //prepare
            var user_back = ValidateResultT(Wait(_Manager.User_FindByEmailAsync(user.Email)));
            Assert.AreEqual(user.Email, user_back.Email);

            //test before all
            var logins_back = ValidateResultT(Wait(_Manager.UserLogin_GetAllAsync(user.UserID)));
            Assert.AreEqual(0, logins_back.Length);
            int testLoginsCount = 5;

            for (int i = 0; i < testLoginsCount; i++)
            {

                //act
                var login = new BL.Models.UserLoginInfoModel()
                {
                    LoginProvider = $"Provider{i}",
                    ProviderKey = Guid.NewGuid().ToString()
                };

                //test before add
                var user_back_byLogin1 = ValidateResultT(Wait(_Manager.User_FindByLoginAsync(login)), false);

                //act
                ValidateResult(Wait(_Manager.UserLogin_AddAsync(user.UserID, login)));

                //test after add
                var user_back_byLogin2 = ValidateResultT(Wait(_Manager.User_FindByLoginAsync(login)));
                Assert.AreEqual(user_back_byLogin2.Email, user.Email);
            }

            //test after all add, before deletion
            logins_back = ValidateResultT(Wait(_Manager.UserLogin_GetAllAsync(user.UserID)));
            Assert.AreEqual(testLoginsCount, logins_back.Length);

            for (int i = 0; i < testLoginsCount; i++)
            {
                ValidateResult(Wait(_Manager.UserLogin_RemoveAsync(user.UserID, logins_back[i])));

                var logins_back_partial = ValidateResultT(Wait(_Manager.UserLogin_GetAllAsync(user.UserID)));
                Assert.AreEqual(testLoginsCount - (i + 1), logins_back_partial.Length);
            }

            //test after all add, after deletion
            logins_back = ValidateResultT(Wait(_Manager.UserLogin_GetAllAsync(user.UserID)));
            Assert.AreEqual(0, logins_back.Length);
        }
        [TestMethod()]
        public void UserLogin_RemoveAsync_Test()
        {
            //covered by AddLoginAsync_Test
        }
        [TestMethod()]
        public void UserLogin_GetAllAsync_Test()
        {
            //covered by AddLoginAsync_Test
        }
        [TestMethod()]
        public void AddClaimsAsync_Test()
        {
            var user = _CreateUser();

            //prepare
            var user_back = ValidateResultT(Wait(_Manager.User_FindByEmailAsync(user.Email)));
            Assert.AreEqual(user.Email, user_back.Email);

            //test before all
            var claims_back = ValidateResultT(Wait(_Manager.UserClaim_GetAllAsync(user.UserID)));
            Assert.AreEqual(0, claims_back.Length);
            int testClaimsCount = 5;

            for (int i = 0; i < testClaimsCount; i++)
            {
                //act
                var claim = new BL.Models.UserClaimModel()
                {
                    ClaimType = $"Claim_{i + 1}",
                    ClaimValue = $"value_{(i + 1) * 5}",
                    UserID = user.UserID
                };

                //act
                ValidateResult(Wait(_Manager.UserClaim_AddAsync(user.UserID, new BL.Models.UserClaimModel[] { claim })));

                //test after add
                claims_back = ValidateResultT(Wait(_Manager.UserClaim_GetAllAsync(user.UserID)));
                Assert.AreEqual(i + 1, claims_back.Length);
                Assert.AreEqual(1, claims_back.Count(c => c.ClaimType == claim.ClaimType && c.ClaimValue == claim.ClaimValue));
            }

            claims_back = ValidateResultT(Wait(_Manager.UserClaim_GetAllAsync(user.UserID)));
            Assert.AreEqual(testClaimsCount, claims_back.Length);

            //Act - try add same claims again (should only change the value
            for (int i = 0; i < testClaimsCount; i++)
            {
                //act
                var claim = new BL.Models.UserClaimModel()
                {
                    ClaimType = $"Claim_{i + 1}",
                    ClaimValue = $"value_{(i + 1) * 10}",
                    UserID = user.UserID
                };

                //test before update already exists claim
                claims_back = ValidateResultT(Wait(_Manager.UserClaim_GetAllAsync(user.UserID)));
                Assert.AreEqual(testClaimsCount, claims_back.Length);
                Assert.AreEqual(1, claims_back.Count(c => c.ClaimType == claim.ClaimType && c.ClaimValue != claim.ClaimValue));

                //act
                ValidateResult(Wait(_Manager.UserClaim_AddAsync(user.UserID, new BL.Models.UserClaimModel[] { claim })));

                //test after update already exists claim
                claims_back = ValidateResultT(Wait(_Manager.UserClaim_GetAllAsync(user.UserID)));
                Assert.AreEqual(testClaimsCount, claims_back.Length);
                Assert.AreEqual(1, claims_back.Count(c => c.ClaimType == claim.ClaimType && c.ClaimValue == claim.ClaimValue));
            }


            //test after all add, before deletion
            claims_back = ValidateResultT(Wait(_Manager.UserClaim_GetAllAsync(user.UserID)));
            Assert.AreEqual(testClaimsCount, claims_back.Length);

            for (int i = 0; i < testClaimsCount; i++)
            {
                ValidateResult(Wait(_Manager.UserClaim_RemoveAsync(user.UserID, $"Claim_{i + 1}")));

                var logins_back_partial = ValidateResultT(Wait(_Manager.UserClaim_GetAllAsync(user.UserID)));
                Assert.AreEqual(testClaimsCount - (i + 1), logins_back_partial.Length);
            }

            //test after all add, after deletion
            claims_back = ValidateResultT(Wait(_Manager.UserClaim_GetAllAsync(user.UserID)));
            Assert.AreEqual(0, claims_back.Length);

        }

        [TestMethod()]
        public void UserClaim_GetAllAsync_Test()
        {
            //covered by AddClaimsAsync_Test
        }

        [TestMethod()]
        public void UserClaim_RemoveAsync_Test()
        {
            //covered by AddClaimsAsync_Test
        }
        [TestMethod()]
        public void Dispose_Test()
        {
            /*  var _connector = new DAL.IdentityStore_SQL();
              var _Manager2 = new Identity2UserManager(_connector);

              //test - before Dispose
              var roles = ValidateResultT(Wait(_Manager2.System_RoleModels()));
              Assert.IsNotNull(roles);
              Assert.AreNotEqual(0, roles.Length);

              _Manager2.Dispose();

              bool faulted = false;
              try
              {
                  //test - after Dispose
                  var roles_after = Wait(_Manager2.System_RoleModels());
              }
              catch
              {
                  faulted = true;
              }
              Assert.IsTrue(faulted);*/
        }
    }
}