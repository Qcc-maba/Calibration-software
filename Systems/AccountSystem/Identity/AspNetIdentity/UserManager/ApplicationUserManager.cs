using Microsoft.AspNet.Identity;
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using Microsoft.AspNet.Identity.Owin;
using Microsoft.Owin.Security.DataProtection;
using Microsoft.Owin;

namespace Maba.AccountSystem.AspNetIdentity.UserManager
{
    public class ApplicationUserManager : UserManager<ApplicationUser>
    {
        #region ctor(s)

        private ApplicationUserManager(IUserStore<ApplicationUser> store)
            : base(store)
        {
            this.MaxFailedAccessAttemptsBeforeLockout = 5;
            this.DefaultAccountLockoutTimeSpan = TimeSpan.FromMinutes(15);
            this.UserLockoutEnabledByDefault = true;
        }

        #endregion

        public static void ApplySettings<KManager, TUser>(UserManager<TUser> userManager, AspNetIdentity.Settings.IdentitySettings settings)
            where TUser : class,IUser
            where KManager : UserManager<TUser>
        {
            #region PasswordValidator

            userManager.PasswordValidator = new PasswordValidator
            {
                RequiredLength = settings.PasswordValidator.RequiredLength,
                RequireNonLetterOrDigit = settings.PasswordValidator.RequireNonLetterOrDigit,
                RequireDigit = settings.PasswordValidator.RequireDigit,
                RequireLowercase = settings.PasswordValidator.RequireLowercase,
                RequireUppercase = settings.PasswordValidator.RequireUppercase,
            };

            #endregion

            #region UserValidator

            userManager.UserValidator = new UserValidator<TUser>(userManager)
            {
                AllowOnlyAlphanumericUserNames = settings.UserValidator.AllowOnlyAlphanumericUserNames,
                RequireUniqueEmail = settings.UserValidator.RequireUniqueEmail
            };

            #endregion

            #region Security

            userManager.UserLockoutEnabledByDefault = settings.Security.UserLockoutEnabledByDefault;
            userManager.DefaultAccountLockoutTimeSpan = settings.Security.DefaultAccountLockoutTimeSpan;
            userManager.MaxFailedAccessAttemptsBeforeLockout = settings.Security.MaxFailedAccessAttemptsBeforeLockout;

            #endregion

            #region twoFactorProvider

            // Register two factor authentication providers. This application uses Phone and Emails as a step of receiving a code for verifying the user
            // You can write your own provider and plug in here.

            foreach (var twoFactorProvider in settings.TokenProviders.Where(t => t.IsEnabled))
            {
                switch (twoFactorProvider.ProviderName)
                {
                    case Settings.PhoneTwoFactorProvider.PROVIDER_NAME:
                        userManager.RegisterTwoFactorProvider("PhoneCode", new PhoneNumberTokenProvider<TUser>
                        {
                            MessageFormat = ((Settings.PhoneTwoFactorProvider)twoFactorProvider).MessageFormat
                        });
                        break;
                    case Settings.EmailTwoFactorProvider.PROVIDER_NAME:
                        userManager.RegisterTwoFactorProvider("EmailCode", new EmailTokenProvider<TUser>
                        {
                            Subject = ((Settings.EmailTwoFactorProvider)twoFactorProvider).Subject,
                            BodyFormat = ((Settings.EmailTwoFactorProvider)twoFactorProvider).BodyFormat
                        });
                        break;
                }
            }

            #endregion

            #region DataProtectionProvider

            var dataProtectionProvider = settings.DataProtectionProvider.CreateDataProtectionProvider();
            var dataProtector = dataProtectionProvider.Create("EmailConfirmation");
            userManager.UserTokenProvider = new DataProtectorTokenProvider<TUser>(dataProtector);

            #endregion
        }

        #region static Create methods

        public static ApplicationUserManager Create(IUserStore<ApplicationUser> UserStore, AspNetIdentity.Settings.IdentitySettings settings)
        {
            return Create(UserStore, null, null, settings);
        }

        public static ApplicationUserManager Create(IUserStore<ApplicationUser> UserStore, IdentityFactoryOptions<ApplicationUserManager> options,
            IOwinContext context, AspNetIdentity.Settings.IdentitySettings settings)
        {
            var userManager = new ApplicationUserManager(UserStore);
           
            ApplySettings<ApplicationUserManager, ApplicationUser>(userManager, settings);

            return userManager;
        }

        #endregion
    }
}
