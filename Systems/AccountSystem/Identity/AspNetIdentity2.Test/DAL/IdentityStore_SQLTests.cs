using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.AccountSystem.AspNetIdentity.Identity2.DAL;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.AccountSystem.AspNetIdentity.Identity2.BL.Models;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.DAL.Test
{
    [TestClass()]
    public class IdentityStore_SQLTests
    {
        public static int Counter = 0;

        #region private members

        private const string ROLE_NAME_PREFIX = "ROLE_TEST";
        private const int ROLE_ID_PREFIX = 90000;
        private const int TIME_OUT = 100000;

        private Random rand = new Random();
        private SystemTimeZone[] TimeZones { get; set; }
        private SystemUIFormat[] SystemUIFormats { get; set; }
        private SystemTemperatureUnit[] TemperatureUnits { get; set; }
        private Role[] Roles { get; set; }

        private List<BaseUser> _Users = new List<BaseUser>();

        #endregion

        #region ctor

        public IdentityStore_SQLTests()
        {
        }

        #endregion

        #region private methods
        private void compareRoles(Role expected, Role r)
        {
            Assert.AreEqual(expected.Name, r.Name);
            Assert.AreEqual(expected.RoleID, r.RoleID);
        }
        private T Wait<T>(Task<T> t)
        {
            Assert.IsTrue(t.Wait(TIME_OUT));

            return t.Result;
        }
        public TestContext TestContext { get; set; }
        private void _checkUser(BaseUserExtendView user)
        {
            var tempUnit = TemperatureUnits.FirstOrDefault(t => t.TypeUnitID == user.TemperatureUnitID);
            Assert.AreEqual(tempUnit.DisplayName, user.Temperature_DisplayName);
            Assert.AreEqual(tempUnit.DisplayUnit, user.Temperature_UnitView);

            var uiFormat = SystemUIFormats.FirstOrDefault(u => u.UIFormatID == user.UIFormatID);
            Assert.AreEqual(uiFormat.CultureCode, user.CultureCode);

            var timeZone = TimeZones.FirstOrDefault(t => t.ZoneID == user.TimeZoneID);
            Assert.AreEqual(timeZone.ZoneID, user.TimeZoneID);
        }
        private void ModifyRandomUser(BaseUser user, int num)
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

            user.EmailConfirmed = num % 2 == 0;
            user.PhoneNumber = $"{ num * 12356}";
            user.PhoneConfirmed = num % 3 == 0;

            var uiFormat = this.SystemUIFormats[num % this.SystemUIFormats.Length];

            user.UIFormatID = uiFormat.UIFormatID;
            user.LongDatePattern = null;
            user.LongTimePattern = null;
            user.ShortTimePattern = null;
            user.ShortDatePattern = null;

            user.PasswordHash = null;
            user.SecurityStamp = null;

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

        private void compareUsers(BaseUser user_back, BaseUser user)
        {
            Assert.AreEqual(user_back.City, user.City);
            Assert.AreEqual(user_back.Country, user.Country);
            Assert.AreEqual(user_back.Email, user.Email);
            Assert.AreEqual(user_back.EmailConfirmed, user.EmailConfirmed);
            Assert.AreEqual(user_back.FirstName, user.FirstName);
            Assert.AreEqual(user_back.ImgURL, user.ImgURL);
            Assert.AreEqual(user_back.LastName, user.LastName);
            Assert.AreEqual(user_back.PasswordHash, user.PasswordHash);
            Assert.AreEqual(user_back.PhoneConfirmed, user.PhoneConfirmed);
            Assert.AreEqual(user_back.PhoneNumber, user.PhoneNumber);
            Assert.AreEqual(user_back.SecurityStamp, user.SecurityStamp);
            Assert.AreEqual(user_back.StreetName, user.StreetName);
            Assert.AreEqual(user_back.StreetNo, user.StreetNo);
            Assert.AreEqual(user_back.TemperatureUnitID, user.TemperatureUnitID);
            Assert.AreEqual(user_back.TimeZoneID, user.TimeZoneID);
            Assert.AreEqual(user_back.UserGuid, user.UserGuid);
            Assert.AreEqual(user_back.UserID, user.UserID);
            Assert.AreEqual(user_back.UserName, user.UserName);
            Assert.AreEqual(user_back.UpdateVersion, user.UpdateVersion);
            Assert.AreEqual(user_back.ZipCode, user.ZipCode);

            Assert.AreEqual(user_back.UIFormatID, user.UIFormatID);
            var uiFormat = this.SystemUIFormats.FirstOrDefault(u => u.UIFormatID == user_back.UIFormatID);

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
            }
        }

        private BaseUserExtendView _CreateUser(IdentityStore_SQL connector, int? num = null, string marker = null)
        {
            //create user
            if (!num.HasValue)
            {
                num = rand.Next(0, 999999);
            }

            var name = this.TestContext.TestName.Length > 40 ? this.TestContext.TestName.Substring(0, 40) : this.TestContext.TestName;

            var newUser = new BaseUser()
            {
                Email = $"{name}@{rand.Next(1000, 50000)}.com"
            };
            if (!string.IsNullOrEmpty(marker))
            {
                newUser.Email = marker + newUser.Email;
            }

            ModifyRandomUser(newUser, num.Value);
            newUser.UserName = newUser.UserName ?? newUser.Email;

            var createResult = Wait(connector.User_CreateAsync(newUser, false));
            Assert.IsTrue(createResult);

            var user_back = Wait(connector.FindByIdAsync(newUser.UserID));
            compareUsers(user_back, newUser);

            Assert.AreEqual(user_back.TimeZoneSystemID, this.TimeZones.FirstOrDefault(z => z.ZoneID == newUser.TimeZoneID).SystemZoneID);
            Assert.AreEqual(user_back.TimeZoneGMTOffset, this.TimeZones.FirstOrDefault(z => z.ZoneID == newUser.TimeZoneID).GMTOffset);

            _Users.Add(user_back);

            return user_back;
        }

        private IdentityStore_SQL _CreateConnector()
        {
            Counter++;
            var connection = new IdentityStore_SQL();

            return connection;
        }

        #endregion

        #region init and clean

        [TestInitialize]
        public void Init()
        {
            var connector = _CreateConnector();

            TimeZones = Wait(connector.GetSystemTimeZonesAsync());
            Assert.IsTrue(TimeZones.All(r => r != null));
            Assert.AreNotEqual(0, TimeZones.Length);

            TemperatureUnits = Wait(connector.GetSystemTemperatureUnitsAsync());
            Assert.IsTrue(TemperatureUnits.All(r => r != null));
            Assert.AreNotEqual(0, TemperatureUnits.Length);

            SystemUIFormats = Wait(connector.GetUIFormatsAsync());
            Assert.IsTrue(SystemUIFormats.All(r => r != null));
            Assert.AreNotEqual(0, SystemUIFormats.Length);

            Roles = Wait(connector.System_Role_GetAll(null)).ToArray();
            Assert.IsTrue(Roles.All(r => r != null));
            Assert.AreNotEqual(0, Roles.Length);

            foreach (var role in Roles.Where(r => r.Name.StartsWith(ROLE_NAME_PREFIX)))
            {
                Assert.IsTrue(Wait(connector.Role_DeleteByIdAsync(role.RoleID)));
            }

            Roles = Roles
                .Where(r => !r.Name.StartsWith(ROLE_NAME_PREFIX))
                .ToArray();
        }

        [TestCleanup]
        public void CleanUp()
        {
            var connector = _CreateConnector();

            foreach (var u in _Users)
            {
                Assert.IsTrue(Wait(connector.User_DeleteByIdAsync(u.UserID)));
            }

            foreach (var role in Roles.Where(r => r.Name.StartsWith(ROLE_NAME_PREFIX)))
            {
                connector.Role_DeleteByIdAsync(role.RoleID);
            }
        }

        #endregion

        [TestMethod()]
        public void FindUsersAsync_Test()
        {
            //parameters
            int totalItems = 20;
            string marker = Guid.NewGuid().ToString().Substring(0, 6);

            //prepare
            var connector = _CreateConnector();

            var users = new List<BaseUser>();
            for (int i = 0; i < totalItems; i++)
            {
                users.Add(_CreateUser(connector, rand.Next(0, 99999), marker));
            }

            for (int _pageSize = 1; _pageSize < totalItems + 1; _pageSize++)
            {

                for (int _pageNumber = 1; _pageNumber < totalItems; _pageNumber++)
                {

                    var expectedItems = users
                                    .OrderBy(u => u.FirstName)
                                    .Skip(_pageSize * (_pageNumber - 1))
                                    .Take(_pageSize)
                                    .ToArray();


                    var itemsResponse = Wait(connector.FindUsersAsync(marker, _pageSize, _pageNumber));

                    Assert.IsNotNull(itemsResponse);
                    Assert.AreEqual(itemsResponse.RequestedPageNumber, _pageNumber);
                    Assert.AreEqual(itemsResponse.RequestedPageSize, _pageSize);

                    Assert.AreEqual(itemsResponse.TotalItems, totalItems);
                    Assert.IsNotNull(itemsResponse.Items);
                    Assert.AreEqual(itemsResponse.Items.Length, expectedItems.Length);

                    for (int userIndex = 0; userIndex < expectedItems.Length; userIndex++)
                    {
                        compareUsers(expectedItems[userIndex], itemsResponse.Items[userIndex]);
                    }
                }

            }


        }

        [TestMethod()]
        public void FindByIdAsync_Test()
        {
            //covered by User_CreateAsync_Test
        }

        [TestMethod()]
        public void FindByUserNameAsync_Test()
        {
            //covered by User_CreateAsync_Test
        }

        [TestMethod()]
        public void FindByEmailAsync_Test()
        {
            //covered by User_CreateAsync_Test
        }

        [TestMethod()]
        public void User_UpdateAsync_Test()
        {
            //covered by User_CreateAsync_Test
        }

        [TestMethod()]
        public void User_CreateAsync_Test()
        {
            var connector = _CreateConnector();

            //create user
            var user = _CreateUser(connector);

            _checkUser(user);

            for (int i = 0; i < 10; i++)
            {
                ModifyRandomUser(user, i);

                Assert.IsTrue(Wait(connector.User_UpdateAsync(user)));
                user.UpdateVersion++;

                //get user back by UserID
                var user_byId_back = Wait(connector.FindByIdAsync(user.UserID));
                compareUsers(user_byId_back, user);

                //get user back by Email
                var user_byEmail_back = Wait(connector.FindByEmailAsync(user.Email));
                compareUsers(user_byEmail_back, user);

                //get user back by UserName
                var user_byUserName_back = Wait(connector.FindByUserNameAsync(user.UserName));
                compareUsers(user_byUserName_back, user);
            }
        }

        [TestMethod()]
        public void User_UpdateSecurityStampAsync_Test()
        {
            var connector = _CreateConnector();

            //create user
            var user = _CreateUser(connector);
            var stamp = Guid.NewGuid().ToString();
            Assert.IsTrue(Wait(connector.User_UpdateSecurityStampAsync(user.UserID, stamp)));

            var user_back = Wait(connector.FindByIdAsync(user.UserID));
            Assert.AreEqual(user_back.SecurityStamp, stamp);
        }

        [TestMethod()]
        public void User_GetPhoneNumberChangeTokenAsync_Test()
        {

            //covered by User_UpdatePhoneNumberChangeTokenAsync_Test
        }

        [TestMethod()]
        public void User_UpdatePhoneNumberChangeTokenAsync_Test()
        {
            var connector = _CreateConnector();

            //create user
            var user = _CreateUser(connector);
            var token = DateTime.UtcNow.Millisecond.ToString();

            Assert.IsTrue(Wait(connector.User_UpdatePhoneNumberChangeTokenAsync(user.UserID, token)));
            var token_back = Wait(connector.User_GetPhoneNumberChangeTokenAsync(user.UserID));
            Assert.IsNotNull(token_back);
            Assert.AreEqual(token_back.UserID, user.UserID);
            Assert.AreEqual(token_back.PhoneNumberChangeToken, token);
        }

        [TestMethod()]
        public void User_DeleteByEmailAsync_Test()
        {
            //prepare
            var connector = _CreateConnector();
            var user = _CreateUser(connector);

            //Act
            Assert.IsTrue(Wait(connector.User_DeleteByEmailAsync(user.Email)));

            //Test
            var deletedUser = Wait(connector.FindByIdAsync(user.UserID));
            Assert.IsNull(deletedUser);
        }

        [TestMethod()]
        public void User_DeleteByIdAsync_Test()
        {
            //prepare
            var connector = _CreateConnector();
            var user = _CreateUser(connector);

            //Act
            Assert.IsTrue(Wait(connector.User_DeleteByIdAsync(user.UserID)));

            //Test
            var deletedUser = Wait(connector.FindByIdAsync(user.UserID));
            Assert.IsNull(deletedUser);
        }

        [TestMethod()]
        public void User_AddClaimAsync_Test()
        {
            //covered by User_GetClaimsAsync_Test
        }

        [TestMethod()]
        public void User_GetClaimsAsync_Test()
        {
            //prepare
            var connector = _CreateConnector();
            var user = _CreateUser(connector);

            //test as empty
            var claims = Wait(connector.User_GetClaimsAsync(user.UserID));
            Assert.AreEqual(0, claims.Count());

            //add and test
            var new_claims = new UserClaim[10];
            for (int i = 0; i < new_claims.Length; i++)
            {
                var c = new UserClaim()
                {
                    ClaimType = $"x{i}",
                    ClaimValue = $"x{i}_value",
                    UserId = user.UserID
                };
                new_claims[i] = c;
                Assert.IsTrue(Wait(connector.User_AddClaimAsync(user.UserID, c)));
            }

            //test them all
            claims = Wait(connector.User_GetClaimsAsync(user.UserID));
            Assert.AreEqual(new_claims.Length, claims.Count());

            for (int i = 0; i < new_claims.Length; i++)
            {
                var c = new_claims[i];
                //before remove
                claims = Wait(connector.User_GetClaimsAsync(user.UserID));
                Assert.AreEqual(1, claims.Count(cc => cc.ClaimType == c.ClaimType && cc.ClaimValue == c.ClaimValue));

                //remove
                Assert.IsTrue(Wait(connector.User_RemoveClaimAsync(user.UserID, c.ClaimType)));

                //test after remove
                claims = Wait(connector.User_GetClaimsAsync(user.UserID)).ToArray();
                Assert.AreEqual(new_claims.Length - (i + 1), claims.Count());
                Assert.IsFalse(claims.Any(cc => cc.ClaimType == c.ClaimType && cc.ClaimValue == c.ClaimValue));
            }

            claims = Wait(connector.User_GetClaimsAsync(user.UserID));
            Assert.AreEqual(0, claims.Count());

        }

        [TestMethod()]
        public void User_RemoveClaimAsync_Test()
        {
            //covered by User_GetClaimsAsync_Test
        }

        [TestMethod()]
        public void Role_FindByIdAsync_Test()
        {
            //covered by Role_CreateAsync_Test
        }

        [TestMethod()]
        public void Role_FindByNameAsync_Test()
        {
            //covered by Role_CreateAsync_Test
        }

        [TestMethod()]
        public void Role_CreateAsync_Test()
        {
            var connector = _CreateConnector();
            var rand = new Random();
            int totalRolesPerGroup = 5;
            var _roles = new List<Role>();
            Role newRole = null;
            for (int roleGroupIndex = 0; roleGroupIndex < 3; roleGroupIndex++)
            {
                var groupIndex = ROLE_ID_PREFIX + roleGroupIndex;

                for (int testIndex = 0; testIndex < totalRolesPerGroup; testIndex++)
                {
                    while (newRole == null || _roles.Any(r => r.RoleID == newRole.RoleID || r.Name == newRole.Name))
                    {
                        var newRoleID = rand.Next(0, 1000);
                        newRole = new Role()
                        {
                            Name = $"{ROLE_NAME_PREFIX}_{newRoleID}",
                            RoleID = ROLE_ID_PREFIX + newRoleID,
                            RoleGroup = groupIndex
                        };
                    }
                    _roles.Add(newRole);

                    //test before add (should be null)
                    var roleback_1_byID = Wait(connector.Role_FindByIdAsync(newRole.RoleID));
                    Assert.IsNull(roleback_1_byID);
                    var roleback_1_byName = Wait(connector.Role_FindByNameAsync(newRole.Name));
                    Assert.IsNull(roleback_1_byName);

                    //Act --------------------------------------------------------------------------
                    Assert.IsTrue(Wait(connector.Role_CreateAsync(newRole)));

                    //Test (exists only once, with/without group filtering)
                    var roles1 = Wait(connector.System_Role_GetAll(groupIndex)).ToArray();
                    Assert.AreEqual(1, roles1.Count(r => r.Name == newRole.Name && r.RoleID == newRole.RoleID));
                    var roles2 = Wait(connector.System_Role_GetAll(null)).ToArray();
                    Assert.AreEqual(1, roles2.Count(r => r.Name == newRole.Name && r.RoleID == newRole.RoleID));

                    //Test - get it back by id
                    var roleback_byID = Wait(connector.Role_FindByIdAsync(newRole.RoleID));
                    Assert.IsNotNull(roleback_byID);
                    compareRoles(newRole, roleback_byID);

                    //Test - get it back by name
                    var roleback_byName = Wait(connector.Role_FindByNameAsync(newRole.Name));
                    Assert.IsNotNull(roleback_byName);
                    compareRoles(newRole, roleback_byName);
                }

                //test group
                var roles1_filterByGroup = Wait(connector.System_Role_GetAll(groupIndex)).ToArray();
                Assert.AreEqual(totalRolesPerGroup, roles1_filterByGroup.Length);
                var roles2_getAll = Wait(connector.System_Role_GetAll(null)).ToArray();
                Assert.IsTrue(roles2_getAll.Length > totalRolesPerGroup);

                Assert.AreEqual(totalRolesPerGroup, roles2_getAll.Count(r => r.RoleGroup == groupIndex));
            }
        }

        [TestMethod()]
        public void Role_DeleteByIdAsync_Test()
        {
            var connector = _CreateConnector();

            for (int testIndex = 0; testIndex < 10; testIndex++)
            {
                var newRoleID = rand.Next(0, 1000);
                var newRole = new Role()
                {
                    Name = $"{ROLE_NAME_PREFIX}_{newRoleID}",
                    RoleID = ROLE_ID_PREFIX + newRoleID,
                    RoleGroup = testIndex * 2
                };

                //Add --------------------------------------------------------------------------
                Assert.IsTrue(Wait(connector.Role_CreateAsync(newRole)));

                //test before delete (should be null) -------------------------------------------
                var roleback_1_byID = Wait(connector.Role_FindByIdAsync(newRole.RoleID));
                Assert.IsNotNull(roleback_1_byID);
                var roleback_1_byName = Wait(connector.Role_FindByNameAsync(newRole.Name));
                Assert.IsNotNull(roleback_1_byName);

                //Delete ------------------------------------------------------------------------
                if (testIndex % 2 == 0)
                {
                    Assert.IsTrue(Wait(connector.Role_DeleteByIdAsync(newRole.RoleID)));
                }
                else
                {
                    Assert.IsTrue(Wait(connector.Role_DeleteByNameAsync(newRole.Name)));
                }

                //test after delete  -------------------------------------------------------------
                var roleback_2_byID = Wait(connector.Role_FindByIdAsync(newRole.RoleID));
                Assert.IsNull(roleback_2_byID);
                var roleback_2_byName = Wait(connector.Role_FindByNameAsync(newRole.Name));
                Assert.IsNull(roleback_2_byName);
            }
        }

        [TestMethod()]
        public void Role_DeleteByNameAsync_Test()
        {
            //covered by Role_DeleteByIdAsync_Test
        }

        [TestMethod()]
        public void Role_UpdateAsync_Test()
        {
            //prepare
            var connector = _CreateConnector();
            var rand = new Random();

            var newRoleID = rand.Next(0, 1000);
            var newRole = new Role()
            {
                Name = $"{ROLE_NAME_PREFIX}_update_{newRoleID}",
                RoleID = ROLE_ID_PREFIX + newRoleID,
                RoleGroup = 0

            };
            Assert.IsTrue(Wait(connector.Role_CreateAsync(newRole)));

            //Act --------------------------------------------------------------------------
            for (int testIndex = 0; testIndex < 5; testIndex++)
            {
                newRole.Name = $"{ROLE_NAME_PREFIX}_N_{rand.Next(0, 10000)}";

                Assert.IsTrue(Wait(connector.Role_UpdateAsync(newRole)));

                //test
                var role_back = Wait(connector.Role_FindByIdAsync(newRole.RoleID));
                compareRoles(role_back, newRole);
            }
        }

        [TestMethod()]
        public void UserInsertRoleAsync_Test()
        {
            //covered by GetUserRolesAsync_Test
        }

        [TestMethod()]
        public void IsUserHasRoleAsync_Test()
        {
            //covered by GetUserRolesAsync_Test
        }

        [TestMethod()]
        public void GetUserRolesAsync_Test()
        {
            //prepare
            var connector = _CreateConnector();
            var user = _CreateUser(connector);

            var user_roles = Wait(connector.GetUserRolesAsync(user.UserID, null))
                                    .ToArray();
            Assert.AreEqual(0, user_roles.Length);

            //act
            for (int i = 0; i < Roles.Length; i++)
            {
                var role = Roles[i];

                //tests before (it's not exists)
                Assert.IsFalse(Wait(connector.IsUserHasRoleAsync(user.UserID, role.RoleID)));

                //insert role
                Assert.IsTrue(Wait(connector.UserInsertRoleAsync(user.UserID, role.RoleID)));

                //test after (it is exist)
                Assert.IsTrue(Wait(connector.IsUserHasRoleAsync(user.UserID, role.RoleID)));

                //get all roles back (make sure it's found in user)
                user_roles = Wait(connector.GetUserRolesAsync(user.UserID, null))
                                    .ToArray();
                Assert.AreEqual(i + 1, user_roles.Length);
                Assert.AreEqual(1, user_roles.Count(r => r.Name == role.Name && r.RoleID == role.RoleID));
            }

            //act2 - remove
            for (int i = 0; i < Roles.Length; i++)
            {
                var role = Roles[i];
                Assert.IsTrue(Wait(connector.RemoveUserRoleAsync(user.UserID, role.RoleID)));

                //test it's not there anymore
                Assert.IsFalse(Wait(connector.IsUserHasRoleAsync(user.UserID, role.RoleID)));
            }

            //act3 - now the user has no role
            user_roles = Wait(connector.GetUserRolesAsync(user.UserID, null))
                    .ToArray();
            Assert.AreEqual(0, user_roles.Length);
        }

        [TestMethod]
        public void Role_GetAll_Test()
        {
            var connector = _CreateConnector();

            var roles = Wait(connector.System_Role_GetAll(null));
            Assert.IsNotNull(roles);
            Assert.AreNotEqual(0, roles.Count());
        }

        [TestMethod()]
        public void RemoveUserRoleAsync_Test()
        {
            //covered by GetUserRolesAsync_Test
        }

        [TestMethod()]
        public void AddUserLoginAsync_Test()
        {
            //covered by GetUserLoginsAsync_Test
        }

        [TestMethod()]
        public void User_UpdateImageAsync_Test()
        {
            //prepare
            var connector = _CreateConnector();
            var newUser = _CreateUser(connector);

            for (int i = 0; i < 3; i++)
            {
                //Act
                var imageUrl = i == 0 ? null : $"http://server.com/image_{i}.png";
                Assert.IsTrue(Wait(connector.User_UpdateImageAsync(newUser.UserID, imageUrl)));

                //Test
                var user_back = Wait(connector.FindByIdAsync(newUser.UserID));
                Assert.AreEqual(user_back.ImgURL, imageUrl);
            }
        }

        [TestMethod()]
        public void RemoveUserLoginAsync_Test()
        {
            //covered by GetUserLoginsAsync_Test
        }

        [TestMethod()]
        public void GetUserLoginsAsync_Test()
        {
            //prepare
            var connector = _CreateConnector();
            var newUser = _CreateUser(connector);

            //test
            var logins_back = Wait(connector.GetUserLoginsAsync(newUser.UserID)).ToArray();
            Assert.AreEqual(0, logins_back.Length);

            var user_logins = new UserLoginInfo[4];
            for (int i = 0; i < user_logins.Length; i++)
            {
                var l = new UserLoginInfo()
                {
                    LoginProvider = $"Provider_{i}",
                    ProviderKey = Guid.NewGuid().ToString()
                };
                user_logins[i] = l;

                //Act - add login
                Assert.IsTrue(Wait(connector.AddUserLoginAsync(newUser.UserID, l)));

                //Test
                logins_back = Wait(connector.GetUserLoginsAsync(newUser.UserID)).ToArray();
                Assert.AreEqual(i + 1, logins_back.Length);
                Assert.AreEqual(1, logins_back.Count(lo => lo.LoginProvider == l.LoginProvider && lo.ProviderKey == l.ProviderKey));
            }


            //Act 2 - remove them all
            for (int i = 0; i < user_logins.Length; i++)
            {
                var l = user_logins[i];
                Assert.IsTrue(Wait(connector.RemoveUserLoginAsync(newUser.UserID, l)));

                //Test
                logins_back = Wait(connector.GetUserLoginsAsync(newUser.UserID)).ToArray();
                Assert.AreEqual(user_logins.Length - (i + 1), logins_back.Length);
                Assert.AreEqual(0, logins_back.Count(lo => lo.LoginProvider == l.LoginProvider && lo.ProviderKey == l.ProviderKey));
            }

            logins_back = Wait(connector.GetUserLoginsAsync(newUser.UserID)).ToArray();
            Assert.AreEqual(0, logins_back.Length);
        }

        [TestMethod()]
        public void FindByLoginUserAsync_Test()
        {
            //prepare
            var connector = _CreateConnector();
            var newUser = _CreateUser(connector);

            //init test
            var logins_back = Wait(connector.GetUserLoginsAsync(newUser.UserID)).ToArray();
            Assert.AreEqual(0, logins_back.Length);

            //Act
            var user_logins = new UserLoginInfo[4];
            for (int i = 0; i < user_logins.Length; i++)
            {
                var l = new UserLoginInfo()
                {
                    LoginProvider = $"Provider_{i}",
                    ProviderKey = Guid.NewGuid().ToString()
                };
                user_logins[i] = l;

                Assert.IsTrue(Wait(connector.AddUserLoginAsync(newUser.UserID, l)));
            }

            //test - find this user using all it's login info records 
            for (int i = 0; i < user_logins.Length; i++)
            {
                var l = user_logins[i];
                var user_back = Wait(connector.FindByLoginUserAsync(l));
                compareUsers(user_back, newUser);
            }

            //test - make sure - null get nothing
            var dummyLogin = new UserLoginInfo()
            {
                LoginProvider = "",
                ProviderKey = ""
            };
            var dummy_user_back = Wait(connector.FindByLoginUserAsync(dummyLogin));
            Assert.IsNull(dummy_user_back);
        }

        [TestMethod()]
        public void GetSystemTimeZones_Test()
        {
            var connection = _CreateConnector();

            var units = Wait(connection.GetSystemTimeZonesAsync());

            Assert.IsNotNull(units);
            Assert.IsTrue(units.Length > 0);

            Assert.IsNotNull(units[0].DaylightName);
            Assert.IsNotNull(units[0].DisplayName);
            Assert.IsNotNull(units[0].StandardName);
            Assert.IsNotNull(units[0].SystemZoneID);

            Assert.IsTrue(units.Any(z => z.GMTOffset > 0));
            Assert.IsTrue(units.Any(z => z.IsDefault));
            Assert.IsTrue(units.All(u => u.ZoneID > 0));
        }

        [TestMethod()]
        public void GetCultureCodes_Test()
        {
            var connection = _CreateConnector();

            var units = Wait(connection.GetUIFormatsAsync());

            Assert.IsNotNull(units);
            Assert.IsTrue(units.Length > 0);

            Assert.IsNotNull(units[0].CultureCode);
            Assert.IsNotNull(units[0].DisplayName);
            Assert.IsNotNull(units[0].LongDatePattern);
            Assert.IsNotNull(units[0].LongTimePattern);
            Assert.IsNotNull(units[0].ShortDatePattern);
            Assert.IsNotNull(units[0].ShortTimePattern);
            Assert.IsNotNull(units[0].YearMonthPattern);
            Assert.IsTrue(units.All(u => u.UIFormatID > 0));
            Assert.IsTrue(units.Any(c => c.StartDayOfWeek > 0));
        }

        [TestMethod()]
        public void GetSystemTemperatureUnits_Test()
        {
            var connection = _CreateConnector();

            var units = Wait(connection.GetSystemTemperatureUnitsAsync());

            Assert.IsNotNull(units);
            Assert.IsTrue(units.Length > 0);

            Assert.IsNotNull(units[0].DisplayName);
            Assert.IsNotNull(units[0].DisplayUnit);

            Assert.IsTrue(units.All(u => u.TypeUnitID > 0));

        }
    }
}