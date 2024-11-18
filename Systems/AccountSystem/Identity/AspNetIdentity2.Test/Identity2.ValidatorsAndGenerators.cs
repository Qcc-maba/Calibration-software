using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Collections.Generic;
using System.Linq;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.Test
{
    [TestClass]
    public class Identity2_ValidatorsAndGenerators
    {
        #region members

        private Settings.ManagerSettings _Settings = null;
        private Connectors.OWINLibrary.Security.DataProtectionProviderSettings _DataProtectionOptions = null;

        #endregion

        #region ctor

        public Identity2_ValidatorsAndGenerators()
        {
            _Settings = new Settings.ManagerSettings();
            _DataProtectionOptions = new Connectors.OWINLibrary.Security.DataProtectionProviderSettings();
        }

        #endregion

        [TestMethod]
        public void PasswordHasher()
        {
            var password1 = "myPassword1";
            var password2 = "myPassword2";

            var hashed1 = Crypto.HashPassword(password1);
            Assert.IsNotNull(hashed1);
            Assert.IsTrue(Crypto.VerifyHashedPassword(hashed1, password1));
            Assert.IsFalse(Crypto.VerifyHashedPassword(hashed1, password1 + "1"));

            var hashed2 = Crypto.HashPassword(password2);
            Assert.IsNotNull(hashed2);
            Assert.IsTrue(Crypto.VerifyHashedPassword(hashed2, password2));
            Assert.IsFalse(Crypto.VerifyHashedPassword(hashed2, password2 + "1"));

            //make 2 password gives different hashes
            Assert.AreNotEqual(hashed1, hashed2);

            //make sure multiple hashing result in different hashes
            string password3 = "mmyyPaas";
            var hashedPasswords = new List<String>();
            for (int i = 0; i < 10; i++)
            {
                var hashed = Crypto.HashPassword(password3);
                Assert.IsTrue(Crypto.VerifyHashedPassword(hashed, password3));
                hashedPasswords.Add(hashed);
            }

            var distinctHashedPasswords = hashedPasswords
                .Distinct()
                .ToArray();
            Assert.AreEqual(distinctHashedPasswords.Length, hashedPasswords.Count);
        }

        [TestMethod]
        public void PasswordValidator()
        {
            var settings = new Settings.PasswordValidatorSettings()
            {
                RequiredLength = 7,
                RequireLowercase = false,
                RequireNonLetterOrDigit = false
            };

            var validator = new Validators.PasswordValidator(settings);

            Assert.IsFalse(validator.ValidateAsync("123456").Result.Succeeded);
            Assert.IsTrue(validator.ValidateAsync("1234567").Result.Succeeded);


            settings.RequireLowercase = true;
            Assert.IsFalse(validator.ValidateAsync("1234567").Result.Succeeded);
            Assert.IsTrue(validator.ValidateAsync("123a567").Result.Succeeded);

            settings.RequireNonLetterOrDigit = true;
            Assert.IsFalse(validator.ValidateAsync("123a567").Result.Succeeded);
            Assert.IsTrue(validator.ValidateAsync("123a_67").Result.Succeeded);
        }

        [TestMethod]
        public void UserValidator()
        {
            var settings = new Settings.UserValidatorSettings()
            {
                AllowOnlyAlphanumericUserNames = true
            };

            var user = new DAL.BaseUser()
            {
                Email = "eitanr@Maba.co.il",
                UserName = "444eitan"
            };

            var validator = new Validators.UserValidator(settings);

            settings.AllowOnlyAlphanumericUserNames = false;
            user.UserName = "444eitan";
            Assert.IsTrue(validator.ValidateAsync(user).Result.Succeeded);
            user.UserName = "eitan";
            Assert.IsTrue(validator.ValidateAsync(user).Result.Succeeded);

            settings.AllowOnlyAlphanumericUserNames = true;
            user.UserName = "444-e_itan";
            Assert.IsFalse(validator.ValidateAsync(user).Result.Succeeded);
            user.UserName = "eitan";
            Assert.IsTrue(validator.ValidateAsync(user).Result.Succeeded);

            //validate email
            user.Email = "eitan";
            Assert.IsFalse(validator.ValidateAsync(user).Result.Succeeded);
            user.Email = "";
            Assert.IsFalse(validator.ValidateAsync(user).Result.Succeeded);

        }

        [TestMethod]
        public void TokenGenerator_ObjectDataFormat()
        {
            var IssueDate = DateTime.UtcNow.AddHours(1);
            var ExpireDate = DateTime.UtcNow.AddHours(5);

            var emailData = new Security.ConfirmEmailData()
            {
                Email = "eitan@Maba.co.il",
                ExpireDate = ExpireDate,
                IssueDate = IssueDate
            };

            var provider = _DataProtectionOptions.CreateDataProtectionProvider();
            var tokenGenerator = new Security.ObjectDataFormat<Security.ConfirmEmailData>(provider.Create("Email"));

            for (int i = 0; i < 2; i++)
            {
                tokenGenerator.SupportZip = i == 0;

                //bytes
                var protectedToken = tokenGenerator.Protect(emailData);
                var unprotectedEmailData = tokenGenerator.Unprotect(protectedToken);

                Assert.AreEqual(unprotectedEmailData.Email, emailData.Email);
                Assert.AreEqual(unprotectedEmailData.ExpireDate, emailData.ExpireDate);
                Assert.AreEqual(unprotectedEmailData.IssueDate, emailData.IssueDate);

                //string
                var protectedToken_STR = tokenGenerator.Protect2String(emailData);
                var unprotectedEmailData_FROM_STR = tokenGenerator.Unprotect(protectedToken_STR);

                Assert.AreEqual(unprotectedEmailData_FROM_STR.Email, emailData.Email);
                Assert.AreEqual(unprotectedEmailData_FROM_STR.ExpireDate, emailData.ExpireDate);
                Assert.AreEqual(unprotectedEmailData_FROM_STR.IssueDate, emailData.IssueDate);
            }
        }

        [TestMethod]
        public void TokenGenerator_ConfirmEmailFormater()
        {
            var IssueDate = DateTime.UtcNow.AddHours(1);
            var ExpireDate = DateTime.UtcNow.AddHours(5);

            var emailData = new Security.ConfirmEmailData()
            {
                Email = "eitan@Maba.co.il",
                ExpireDate = ExpireDate,
                IssueDate = IssueDate
            };

            var provider = _DataProtectionOptions.CreateDataProtectionProvider();
            var tokenGenerator = new Security.ConfirmEmailFormater(provider.Create("Email"));

            //bytes
            var protectedToken = tokenGenerator.Protect(emailData);
            var unprotectedEmailData = tokenGenerator.Unprotect(protectedToken);

            Assert.AreEqual(unprotectedEmailData.Email, emailData.Email);
            Assert.AreEqual(unprotectedEmailData.ExpireDate, emailData.ExpireDate);
            Assert.AreEqual(unprotectedEmailData.IssueDate, emailData.IssueDate);

            //string
            var protectedToken_STR = tokenGenerator.Protect2String(emailData);
            var unprotectedEmailData_FROM_STR = tokenGenerator.Unprotect(protectedToken_STR);

            Assert.AreEqual(unprotectedEmailData_FROM_STR.Email, emailData.Email);
            Assert.AreEqual(unprotectedEmailData_FROM_STR.ExpireDate, emailData.ExpireDate);
            Assert.AreEqual(unprotectedEmailData_FROM_STR.IssueDate, emailData.IssueDate);
        }

    }
}
