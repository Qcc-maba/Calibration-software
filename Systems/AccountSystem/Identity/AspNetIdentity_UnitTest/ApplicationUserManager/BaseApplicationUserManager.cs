using System;
using System.Linq;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Threading.Tasks;
using Microsoft.AspNet.Identity;
using System.Threading;
using System.Collections.Generic;
using System.Web;
using System.Security.Policy;
using Microsoft.AspNet.Identity.Owin;
using System.Security.Claims;

namespace Maba.AccountSystem.AspNetIdentity.UserManager.UnitTest
{
    public abstract class BaseApplicationUserManager
    {
        #region members

        private ApplicationUserManager userManager = null;

        private RoleManager.ApplicationRoleManager roleManager = null;

        #endregion



        [TestInitialize]
        public void TestInit()
        {
            userManager = CreateManager();
            roleManager = CreateRoleManager();
        }

        #region private function

        private ApplicationUserManager CreateManager()
        {
            var settings = new Settings.IdentitySettings()
            {
                PasswordValidator = new Settings.PasswordValidatorSettings()
                {
                    RequireDigit = true,
                    RequireNonLetterOrDigit = true
                }
            };

            var _manager = OnCreateManager(settings);

            _manager.EmailService = new TestableIdentityMessageService();
            _manager.SmsService = new TestableIdentityMessageService();

            return _manager;
        }

        private ApplicationUser CreateUser(string userName, string email, Action<ApplicationUser> modifyUserAction)
        {
            ApplicationUser user = new ApplicationUser
            {
                FirstName = "reli",
                LastName = "perez",
                UserName = userName,
                Email = email
            };

            if (modifyUserAction != null)
            {
                modifyUserAction(user);
            }
            var createResult = userManager.Create(user);

            Assert.IsTrue(createResult.Succeeded);

            long _id = -1;
            Assert.IsTrue(long.TryParse(user.Id, out _id));
            Assert.IsTrue(_id >= 0);
            Assert.IsFalse(String.IsNullOrEmpty(user.Id));

            return user;
        }

        private ApplicationUser CreateUser(string userName, string email)
        {
            return CreateUser(userName, email, null);
        }

        private ApplicationUser CreateUser(string userName)
        {
           
            string email = string.Format("user_{0}@Maba.co.il", Guid.NewGuid().ToString().Substring(0, 5));
            return CreateUser(userName, email, null);
        }
        private void DeleteUser(ApplicationUser user)
        {
            Assert.IsNotNull(userManager.FindById(user.Id));

            var deletResult = userManager.Delete(user);
            Assert.IsTrue(deletResult.Succeeded);

            Assert.IsNull(userManager.FindById(user.Id));
        }

        private void CompareUsers(ApplicationUser user1, ApplicationUser user2)
        {
            Assert.IsNotNull(user1);
            Assert.IsNotNull(user2);

            Assert.AreEqual(user1.Id, user2.Id);
            Assert.AreEqual(user1.FirstName, user2.FirstName);
            Assert.AreEqual(user1.LastName, user2.LastName);
            Assert.AreEqual(user1.UserName, user2.UserName);
            Assert.AreEqual(user1.UserGuid, user2.UserGuid);
        }

        #endregion

        #region Unit Tests

        [TestMethod]
        public void Roles_AllRoleTests()
        {
            var user = CreateUser("RoleUser" + Guid.NewGuid().ToString().Substring(2, 5));

            var RoleList = new List<RoleManager.Role>() { 
                new RoleManager.Role() { Id = "1", Name = CONSTANTS.ROLE_ADMIN + "22" }, 
                new RoleManager.Role() { Id = "2", Name = CONSTANTS.ROLE_END_USER + "22" }, 
                new RoleManager.Role() { Id = "3", Name = CONSTANTS.ROLE_PROJECT_USER + "22" } };

            foreach (var role in RoleList)
            {
                var addRole_result = roleManager.Create(role);
                Assert.IsTrue(addRole_result.Succeeded);
            }

            //run twice 
            //i=0 :: using AddToRole / RemoveFromRole
            //i=1 :: using AddToRoles / RemoveFromRoles
            for (int i = 0; i < 1; i++)
            {
                #region add roles

                if (i == 0)
                {
                    foreach (var item in RoleList)
                    {
                        var addResult = userManager.AddToRole(user.Id, item.Name);
                        Assert.IsTrue(addResult.Succeeded);
                        Assert.IsTrue(userManager.IsInRole(user.Id, item.Name));
                    }
                }
                else
                {
                    var addResult = userManager.AddToRoles(user.Id, RoleList.Select(U=>U.Id).ToArray());
                    Assert.IsTrue(addResult.Succeeded);
                }

                var userRoleList_add = userManager.GetRoles(user.Id).ToList();
                foreach (var item in userRoleList_add)
                {
                    Assert.IsTrue(RoleList.FirstOrDefault(u=>u.Name == item) !=null);
                }

                #endregion

                #region remove roles

                if (i == 0)
                {
                    foreach (var item in RoleList)
                    {
                        var removeResult = userManager.RemoveFromRole(user.Id, item.Name);
                        Assert.IsTrue(removeResult.Succeeded);
                        Assert.IsFalse(userManager.IsInRole(user.Id, item.Name));
                    }
                }
                else
                {
                    var removeResult = userManager.RemoveFromRoles(user.Id, RoleList.Select(U => U.Name).ToArray());
                    Assert.IsTrue(removeResult.Succeeded);
                }

                var userRoleList_afterRemove = userManager.GetRoles(user.Id);
                Assert.IsTrue(userRoleList_afterRemove == null || userRoleList_afterRemove.Count == 0);

                #endregion
            }
        }

        [TestMethod]
        public void User_Create()
        {
            var user = CreateUser("User_Actions" + Guid.NewGuid().ToString().Substring(2, 5));

            #region Update

            string _FirstName = "First_Changed1";
            string _LastName = "Last_Changed1";

            user.FirstName = _FirstName;
            user.LastName = _LastName;

            var updateUserResult = userManager.Update(user);
            Assert.IsTrue(updateUserResult.Succeeded);

            var foundUser_byId = userManager.FindById(user.Id);
            CompareUsers(user, foundUser_byId);
            Assert.AreEqual(user.FirstName, _FirstName);
            Assert.AreEqual(user.LastName, _LastName);

            #endregion

            #region Delete

            DeleteUser(user);

            #endregion
        }

        [TestMethod]
        public void User_Logins()
        {
            var user = CreateUser("User_Logins" + Guid.NewGuid().ToString().Substring(2, 5));

            int loginsTotal = 5;
            for (int i = 0; i < loginsTotal; i++)
            {
                var addLoginResult = userManager.AddLogin(user.Id, new UserLoginInfo("loginProvider_" + i.ToString(), "loginKey_" + i.ToString()));
                Assert.IsTrue(addLoginResult.Succeeded);
            }

            var userLogins = userManager.GetLogins(user.Id);
            Assert.IsTrue(userLogins != null && userLogins.Count == loginsTotal);

            foreach (var userLogin in userLogins)
            {
                userManager.RemoveLogin(user.Id, userLogin);
                loginsTotal--;
                var currentUserLogins = userManager.GetLogins(user.Id);
                Assert.IsTrue(currentUserLogins != null && currentUserLogins.Count == loginsTotal);
            }
        }

        [TestMethod]
        public void User_AllFindTests()
        {
            var user = CreateUser("FindAsyncUser" + Guid.NewGuid().ToString().Substring(2, 5));

            var foundUser_byId = userManager.FindById(user.Id);
            CompareUsers(user, foundUser_byId);

            var foundUser_byName = userManager.FindByName(user.UserName);
            CompareUsers(user, foundUser_byName);
        }

        [TestMethod]
        public void User_EmailTests()
        {
            //validate email support
            Assert.IsTrue(userManager.SupportsUserEmail);

            var user = CreateUser("UserEmail" + Guid.NewGuid().ToString().Substring(2, 5));

            //validate no email
            Assert.IsFalse(userManager.IsEmailConfirmed(user.Id));

            //add none-confirmed email
            var newEmail = "relip_"+Guid.NewGuid().ToString().Substring(2, 5)+"@Maba.co.il";
            var setEmailResult = userManager.SetEmail(user.Id, newEmail);
            Assert.IsTrue(setEmailResult.Succeeded);
            Assert.IsFalse(userManager.IsEmailConfirmed(user.Id));
            Assert.AreEqual(newEmail, userManager.GetEmail(user.Id));

            //confirm email
            var confirmToken = userManager.GenerateEmailConfirmationToken(user.Id);
            var confirmEmailResult = userManager.ConfirmEmail(user.Id, confirmToken);
            Assert.IsTrue(confirmEmailResult.Succeeded);
            Assert.IsTrue(userManager.IsEmailConfirmed(user.Id));
            Assert.AreEqual(newEmail, userManager.GetEmail(user.Id));

            //find exists and not exists
            var user2 = userManager.FindByEmail(newEmail);
            CompareUsers(user, user2);

            var user3 = userManager.FindByEmail("w" + newEmail);
            Assert.IsNull(user3);
        }

        [TestMethod]
        public void User_SecurityStampTests()
        {
            //validate it's supported
            Assert.IsTrue(userManager.SupportsUserSecurityStamp);

            var securityStampUser = CreateUser("StampUser"+ Guid.NewGuid().ToString().Substring(2, 5));
            var updateSecurityStampResult = userManager.UpdateSecurityStamp(securityStampUser.Id);
            Assert.IsTrue(updateSecurityStampResult.Succeeded);
            var securityStamp = userManager.GetSecurityStamp(securityStampUser.Id);
            Assert.IsFalse(String.IsNullOrEmpty(securityStamp));
        }

        [TestMethod]
        public void AllPasswordMethodTest()
        {
            //validate we support Password actions
            Assert.IsTrue(userManager.SupportsUserPassword);

            var passwordUser = CreateUser("PasswordUser" + Guid.NewGuid().ToString().Substring(2, 5));
            Assert.IsFalse(userManager.HasPassword(passwordUser.Id));

            string password1 = "123_456chdfkjA";
            string password2 = "QQQ_456chdfkjA";
            string password3 = "ZZZ_456chdfkjA";

            //Add password1
            var addPasswordResult1 = userManager.AddPassword(passwordUser.Id, password1);
            Assert.IsTrue(addPasswordResult1.Succeeded);
            Assert.IsTrue(userManager.HasPassword(passwordUser.Id));
            var userDB = userManager.FindById(passwordUser.Id);
            Assert.IsTrue(userManager.CheckPassword(userDB, password1));
            Assert.IsFalse(userManager.CheckPassword(userDB, password2));

            //change password (old password is mandatory)
            var changePasswordResult1 = userManager.ChangePassword(passwordUser.Id, "hhh", password2);
            Assert.IsFalse(changePasswordResult1.Succeeded);
            var changePasswordResult2 = userManager.ChangePassword(passwordUser.Id, password1, password2);
            Assert.IsTrue(changePasswordResult2.Succeeded);

            //add another passwords should fail
            var addPasswordResult2 = userManager.AddPassword(passwordUser.Id, password1);
            Assert.IsFalse(addPasswordResult2.Succeeded);
            var addPasswordResult3 = userManager.AddPassword(passwordUser.Id, password2);
            Assert.IsFalse(addPasswordResult3.Succeeded);

            //reset password
            var resetPasswordToken = userManager.GeneratePasswordResetToken(passwordUser.Id);
            Assert.IsFalse(String.IsNullOrEmpty(resetPasswordToken));
            var resetPasswordResult = userManager.ResetPassword(passwordUser.Id, resetPasswordToken, password3);
            Assert.IsTrue(resetPasswordResult.Succeeded);
             userDB = userManager.FindById(passwordUser.Id);
            Assert.IsFalse(userManager.CheckPassword(userDB, password1));
            Assert.IsFalse(userManager.CheckPassword(userDB, password2));
            Assert.IsTrue(userManager.CheckPassword(userDB, password3));

            //remove password
            var removePasswordResult = userManager.RemovePassword(passwordUser.Id);
            Assert.IsTrue(removePasswordResult.Succeeded);
            //after remove - all previous passwords should be failed
            userDB = userManager.FindById(passwordUser.Id);
            Assert.IsFalse(userManager.CheckPassword(userDB, password1));
            Assert.IsFalse(userManager.CheckPassword(userDB, password2));
            Assert.IsFalse(userManager.CheckPassword(userDB, password3));
            Assert.IsFalse(userManager.HasPassword(userDB.Id));
        }

        [TestMethod]
        public void AllLockoutTest()
        {
            //validate Lockout is supported
            Assert.IsTrue(userManager.SupportsUserLockout);
            Assert.IsTrue(userManager.UserLockoutEnabledByDefault);


            //validate defaults settings make sense
            Assert.IsTrue(userManager.MaxFailedAccessAttemptsBeforeLockout >= 3);
            Assert.IsTrue(userManager.DefaultAccountLockoutTimeSpan >= TimeSpan.FromMinutes(5));

            #region create users and play "with UserLockoutEnabledByDefault"

            userManager.UserLockoutEnabledByDefault = false;
            var lockoutUser1 = CreateUser("LockoutUser_" + Guid.NewGuid().ToString().Substring(2, 5));
            Assert.IsFalse(userManager.GetLockoutEnabled(lockoutUser1.Id));
            Assert.IsTrue(userManager.SetLockoutEnabled(lockoutUser1.Id, true).Succeeded);
            Assert.IsTrue(userManager.GetLockoutEnabled(lockoutUser1.Id));

            userManager.UserLockoutEnabledByDefault = true;

            var lockoutUser2 = CreateUser("LockoutUser_" + Guid.NewGuid().ToString().Substring(2, 5));
            Assert.IsTrue(userManager.GetLockoutEnabled(lockoutUser2.Id));
            Assert.IsTrue(userManager.SetLockoutEnabled(lockoutUser2.Id, false).Succeeded);
            Assert.IsFalse(userManager.GetLockoutEnabled(lockoutUser2.Id));
            Assert.IsTrue(userManager.SetLockoutEnabled(lockoutUser2.Id, true).Succeeded);
            Assert.IsTrue(userManager.GetLockoutEnabled(lockoutUser2.Id));
            Assert.IsFalse(userManager.IsLockedOut(lockoutUser2.Id));

            Assert.IsTrue(userManager.SetLockoutEndDate(lockoutUser2.Id, new DateTimeOffset(DateTime.UtcNow.AddHours(1))).Succeeded);
            Assert.IsTrue(userManager.IsLockedOut(lockoutUser2.Id));
            Assert.IsTrue(userManager.SetLockoutEndDate(lockoutUser2.Id, new DateTimeOffset(DateTime.UtcNow.AddHours(-1))).Succeeded);
            Assert.IsFalse(userManager.IsLockedOut(lockoutUser2.Id));

            #endregion

            string password = "rightPassword_1234";
            string password2 = "rightPassword_2_1234";
            string wrongPassword = "wrongPassword";

            #region check Lockout auto lock when execeed tries more than [userManager.MaxFailedAccessAttemptsBeforeLockout]

            var addFirstPasswordResult = userManager.AddPassword(lockoutUser2.Id, password);
            Assert.IsTrue(addFirstPasswordResult.Succeeded);
            ApplicationUser userDB = null;
            for (int i = 0; i < userManager.MaxFailedAccessAttemptsBeforeLockout; i++)
            {
                userDB = userManager.FindById(lockoutUser2.Id);
                Assert.IsFalse(userManager.CheckPassword(userDB, wrongPassword));
                Assert.IsFalse(userManager.IsLockedOut(lockoutUser2.Id));

                Assert.IsTrue(userManager.AccessFailed(lockoutUser2.Id).Succeeded);
                Assert.AreEqual(i + 1, userManager.GetAccessFailedCount(lockoutUser2.Id));
            }

            Assert.IsFalse(userManager.CheckPassword(userDB, wrongPassword));
            Assert.IsTrue(userManager.AccessFailed(lockoutUser2.Id).Succeeded);

            Assert.IsTrue(userManager.IsLockedOut(lockoutUser2.Id));

            #endregion

            #region test - resetting user access

            //reset access failed count
            Assert.IsTrue(userManager.ResetAccessFailedCount(lockoutUser2.Id).Succeeded);
            Assert.AreEqual(0, userManager.GetAccessFailedCount(lockoutUser2.Id));

            //still lockedout
            Assert.IsTrue(userManager.IsLockedOut(lockoutUser2.Id));

            //reset access and password
            var resetToken = userManager.GeneratePasswordResetToken(lockoutUser2.Id);
            var resetPasswordResult = userManager.ResetPassword(lockoutUser2.Id, resetToken, password2);
            Assert.IsTrue(resetPasswordResult.Succeeded);
            userDB = userManager.FindById(lockoutUser2.Id);
            Assert.IsFalse(userManager.CheckPassword(userDB, password));
            Assert.IsTrue(userManager.CheckPassword(userDB, password2));

            #endregion
        }

        [TestMethod]
        public void ForgotPassword()
        {
            //Forgot -> send mail with link -> reset password -> reset succeeded
            var user = CreateUser("ForgotPassword_" + Guid.NewGuid().ToString().Substring(2, 5));
            user.EmailConfirmed = true;
            user.Email = "reli_1@walla.co.il";
            var updateUserResult = userManager.Update(user);
            Assert.IsTrue(updateUserResult.Succeeded);
           
            ////Start Here Forgot Password
            var passwordResetCode = userManager.GeneratePasswordResetToken(user.Id);
            var callbackUrl = String.Format("http://localhost:65031/Account/ResetPassword?code={0}&userId={1}", passwordResetCode, user.Id);

            //reset mails
            var emailService = userManager.EmailService as TestableIdentityMessageService;
            emailService.Clear();

            string _subject = "Reset Password";
            string _body = String.Format("Please reset your password by clicking here: <a href=\"{0}\">link</a>", callbackUrl);
            Assert.IsFalse(emailService._SentMessages.Any(m => m.Destination == user.Email && m.Subject == _subject && m.Body == _body));

            userManager.SendEmail(user.Id, _subject, _body);

            //make sure email was sent.
            Assert.IsTrue(emailService._SentMessages.Any(m => m.Destination == user.Email && m.Subject == _subject && m.Body == _body));
        }

        [TestMethod]
        public void ResetPassword()
        {
            var user = CreateUser("ResetPassword_" + Guid.NewGuid().ToString().Substring(2, 5));
            string originalPassword = "aD_656565";

            var addPasswordResult = userManager.AddPassword(user.Id, originalPassword);
            Assert.IsTrue(addPasswordResult.Succeeded);
            var userp = userManager.FindById(user.Id);
            Assert.IsTrue(userManager.CheckPassword(userp, originalPassword));

            //get the code from the Forgot Password callbackUrl
            var code = userManager.GeneratePasswordResetToken(user.Id);
            string NewPassword = "1234578_AAaa";

            var result = userManager.ResetPassword(user.Id, code, NewPassword);
            Assert.IsTrue(result.Succeeded);
             userp = userManager.FindById(user.Id);
             Assert.IsFalse(userManager.CheckPassword(userp, originalPassword));
             Assert.IsTrue(userManager.CheckPassword(userp, NewPassword));
        }

        [TestMethod]
        public void RegisterUser()
        {
            //Create -> send mail with link -> ConfirmEmail -> Confirm Email succeeded
            var RegisterUser = CreateUser("ConfirmUser_" + Guid.NewGuid().ToString().Substring(2, 5));
            Assert.IsFalse(RegisterUser.EmailConfirmed);
            Assert.IsFalse(userManager.IsEmailConfirmed(RegisterUser.Id));
            RegisterUser.Email = "eitanr@Maba.co.il";
            userManager.Update(RegisterUser);
            var token = userManager.GenerateEmailConfirmationToken(RegisterUser.Id);
            Assert.IsNotNull(token);

            //reset mails
            var emailService = userManager.EmailService as TestableIdentityMessageService;

            string _subject = "Confirm your account";
            string _body = "Please confirm your account by clicking this link: <a href=\""
                                               + "http://localhost:65031/Account/ConfirmEmail?code="
                                               + token + "&userId=" + RegisterUser.Id + "\">link</a>";

            Assert.IsFalse(emailService._SentMessages.Any(m => m.Destination == RegisterUser.Email && m.Subject == _subject && m.Body == _body));

            userManager.SendEmail(RegisterUser.Id, _subject, _body);

            //make sure email was sent.
            Assert.IsTrue(emailService._SentMessages.Any(m => m.Destination == RegisterUser.Email && m.Subject == _subject && m.Body == _body));


            var confirmEmailResult = userManager.ConfirmEmail(RegisterUser.Id, token);
            Assert.IsTrue(confirmEmailResult.Succeeded);
            var u = userManager.FindByEmail(RegisterUser.Email);
            
            Assert.IsTrue(u.EmailConfirmed);
            Assert.IsTrue(userManager.IsEmailConfirmed(RegisterUser.Id));

        }

        [TestMethod]
        public void Send_SMSTest()
        {
            var user = CreateUser("SMSTest_" + Guid.NewGuid().ToString().Substring(2, 5));
            user.PhoneNumber = "972502661994";
            user.PhoneConfirmed = true;
            Assert.IsTrue(userManager.Update(user).Succeeded);

            //reset mails
            var smsService = userManager.SmsService as TestableIdentityMessageService;

            string _message = "bla bla";

            Assert.IsFalse(smsService._SentMessages.Any(m => m.Destination == user.PhoneNumber && m.Body == _message));

            userManager.SendSms(user.Id, _message);

            Assert.IsTrue(smsService._SentMessages.Any(m => m.Destination == user.PhoneNumber && m.Body == _message));
        }

        [TestMethod]
        public void AllPhoneNumberTest()
        {
            Assert.IsTrue(userManager.SupportsUserPhoneNumber);

            var user = CreateUser("PhoneNumber_" + Guid.NewGuid().ToString().Substring(2, 5));
            Assert.IsFalse(user.PhoneConfirmed);
            Assert.IsFalse(userManager.IsPhoneNumberConfirmed(user.Id));

            //change by "SetPhoneNumber"
            string _phoneNumber1 = "1234567";
            var setPhoneResult = userManager.SetPhoneNumber(user.Id, _phoneNumber1);
            var userDB = userManager.FindById(user.Id);
            Assert.IsTrue(setPhoneResult.Succeeded);
            Assert.AreEqual(userDB.PhoneNumber, _phoneNumber1);
            Assert.AreEqual(_phoneNumber1, userManager.GetPhoneNumber(user.Id));
            //never confirmed
            Assert.IsFalse(userDB.PhoneConfirmed);
            Assert.IsFalse(userManager.IsPhoneNumberConfirmed(user.Id));

            //change by "GenerateChangePhoneNumberToken / ChangePhoneNumber"
            string _phoneNumber2 = "3424324";
            var token_1 = userManager.GenerateChangePhoneNumberToken(user.Id, _phoneNumber2);
            Assert.IsTrue(userManager.VerifyChangePhoneNumberToken(user.Id, token_1, _phoneNumber2));
            Assert.IsFalse(userManager.VerifyChangePhoneNumberToken(user.Id, token_1, _phoneNumber1));
            Assert.IsFalse(userManager.VerifyChangePhoneNumberToken(user.Id, "wrongToken", _phoneNumber2));

            var changePhone2_Result = userManager.ChangePhoneNumber(user.Id, _phoneNumber2, token_1);
            Assert.IsTrue(changePhone2_Result.Succeeded);
            userDB = userManager.FindById(user.Id);
            Assert.AreEqual(userDB.PhoneNumber, _phoneNumber2);
            Assert.AreEqual(_phoneNumber2, userManager.GetPhoneNumber(user.Id));
            Assert.IsTrue(userDB.PhoneConfirmed);
            Assert.IsTrue(userManager.IsPhoneNumberConfirmed(user.Id));
            //make sure token no longer avilable
            Assert.IsFalse(userManager.VerifyChangePhoneNumberToken(user.Id, token_1, _phoneNumber2));


            //change by "SetPhoneNumber"
            string _phoneNumber3 = "11223344565";
            var setPhoneResult3 = userManager.SetPhoneNumber(user.Id, _phoneNumber3);
            Assert.IsTrue(setPhoneResult.Succeeded);
            userDB = userManager.FindById(user.Id);
            Assert.AreEqual(userDB.PhoneNumber, _phoneNumber3);
            Assert.AreEqual(_phoneNumber3, userManager.GetPhoneNumber(user.Id));
            //phone should not be confirmed after change.
            Assert.IsFalse(userDB.PhoneConfirmed);
            Assert.IsFalse(userManager.IsPhoneNumberConfirmed(user.Id));
            var token_3 = userManager.GenerateChangePhoneNumberToken(user.Id, _phoneNumber3);
            var changePhone3_Result = userManager.ChangePhoneNumber(user.Id, _phoneNumber3, token_3);
            Assert.IsTrue(changePhone3_Result.Succeeded);


        }
        /**/
        [TestMethod]
        public void AllUserClaimTest()
        {
            ///TODO: userManager.CreateIdentity
            var user = CreateUser("UserClaim" + Guid.NewGuid().ToString().Substring(2, 5));
            var listClaim = new List<Claim>() { new Claim(ClaimTypes.Country, "iiii"), new Claim(ClaimTypes.CookiePath, "dfssfds") };
            var taskAddClaimAsync = userManager.AddClaimAsync(user.Id, listClaim[0]);
            taskAddClaimAsync.Wait();
            taskAddClaimAsync = userManager.AddClaimAsync(user.Id, listClaim[1]);
            taskAddClaimAsync.Wait();
            Assert.IsTrue(taskAddClaimAsync.Result.Succeeded);


            taskAddClaimAsync = userManager.RemoveClaimAsync(user.Id, listClaim[1]);
            taskAddClaimAsync.Wait();
            Assert.IsTrue(taskAddClaimAsync.Result.Succeeded);

            var listClaimFromUser = userManager.GetClaims(user.Id) as List<Claim>;

            var c = listClaimFromUser.Find(u => u.Type == listClaim[0].Type && u.Value == listClaim[0].Value);

            Assert.IsTrue(c != null);

            var c1 = listClaimFromUser.Find(u => u.Type == listClaim[1].Type && u.Value == listClaim[1].Value);

            Assert.IsTrue(c1 == null);
        }

        #endregion

        #region abstract methods

        protected abstract ApplicationUserManager OnCreateManager(Settings.IdentitySettings settings);
        protected abstract RoleManager.ApplicationRoleManager CreateRoleManager();
        #endregion

        #region Reli ???

        //[TestMethod]
        //public void LoginUser()
        //{
        //    Assert.IsTrue(false);
        //}

        //[TestMethod]
        //public void LogOutUser()
        //{
        //    Assert.IsTrue(false);
        //}

        #endregion
    }
}
