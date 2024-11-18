using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Net.Mail;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.Validators
{
    public class UserValidator : IValidator<DAL.BaseUser>
    {
        #region properties

        public Settings.UserValidatorSettings Options { get; set; }

        #endregion

        #region ctor

        public UserValidator(Settings.UserValidatorSettings options)
        {
            this.Options = options;
        }

        #endregion

        #region validating methods

        /// <summary>
        ///     Validates a user before saving
        /// </summary>
        /// <param name="item"></param>
        /// <returns></returns>
        public virtual Task<ActionResult> ValidateAsync(DAL.BaseUser item)
        {
            return Task.Run<ActionResult>(() =>
                {

                    if (item == null)
                    {
                        throw new ArgumentNullException("item");
                    }
                    var errors = new List<string>();
                    ValidateUserName(item, errors);

                    ValidateEmailAsync(item, errors);

                    if (errors.Count > 0)
                    {
                        return new ActionResult(errors.ToArray());
                    }

                    return ActionResult.Success;
                });
        }

        #endregion

        #region private methods

        private void ValidateUserName(DAL.BaseUser user, List<string> errors)
        {
            if (string.IsNullOrWhiteSpace(user.UserName))
            {
                errors.Add(String.Format(CultureInfo.CurrentCulture, Resources.PropertyTooShort, "Name"));
            }
            else if (Options.AllowOnlyAlphanumericUserNames && !Regex.IsMatch(user.UserName, @"^[A-Za-z0-9@_\.]+$"))
            {
                // If any characters are not letters or digits, its an illegal user name
                errors.Add(String.Format(CultureInfo.CurrentCulture, Resources.InvalidUserName, user.UserName));
            }
        }

        // make sure email is not empty, valid, and unique
        private void ValidateEmailAsync(DAL.BaseUser user, List<string> errors)
        {
            if (string.IsNullOrWhiteSpace(user.Email))
            {
                errors.Add(String.Format(CultureInfo.CurrentCulture, Resources.PropertyTooShort, "Email"));
                return;
            }
            try
            {
                var m = new MailAddress(user.Email);
            }
            catch (FormatException)
            {
                errors.Add(String.Format(CultureInfo.CurrentCulture, Resources.InvalidEmail, user.Email));
                return;
            }
        }

        #endregion

    }
}
