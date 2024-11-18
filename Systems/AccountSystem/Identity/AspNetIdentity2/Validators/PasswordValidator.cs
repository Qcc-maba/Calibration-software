using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.Validators
{
    public class PasswordValidator : IValidator<string>
    {
        #region properties

        public Settings.PasswordValidatorSettings Options { get; set; }

        #endregion

        #region ctor

        public PasswordValidator(Settings.PasswordValidatorSettings options)
        {
            Options = options;
        }

        #endregion

        #region Validating methods

        /// <summary>
        /// Returns a flag indicting whether the supplied character is a digit.
        /// </summary>
        /// <param name="c">The character to check if it is a digit.</param>
        /// <returns>True if the character is a digit, otherwise false.</returns>
        public virtual bool IsDigit(char c)
        {
            return c >= '0' && c <= '9';
        }

        /// <summary>
        /// Returns a flag indicting whether the supplied character is a lower case ASCII letter.
        /// </summary>
        /// <param name="c">The character to check if it is a lower case ASCII letter.</param>
        /// <returns>True if the character is a lower case ASCII letter, otherwise false.</returns>
        public virtual bool IsLower(char c)
        {
            return c >= 'a' && c <= 'z';
        }

        /// <summary>
        /// Returns a flag indicting whether the supplied character is an upper case ASCII letter.
        /// </summary>
        /// <param name="c">The character to check if it is an upper case ASCII letter.</param>
        /// <returns>True if the character is an upper case ASCII letter, otherwise false.</returns>
        public virtual bool IsUpper(char c)
        {
            return c >= 'A' && c <= 'Z';
        }

        /// <summary>
        /// Returns a flag indicting whether the supplied character is an ASCII letter or digit.
        /// </summary>
        /// <param name="c">The character to check if it is an ASCII letter or digit.</param>
        /// <returns>True if the character is an ASCII letter or digit, otherwise false.</returns>
        public virtual bool IsLetterOrDigit(char c)
        {
            return IsUpper(c) || IsLower(c) || IsDigit(c);
        }

        #endregion

        #region IValidator members

        public Task<ActionResult> ValidateAsync(string item)
        {
            if (item == null)
            {
                throw new ArgumentNullException("password");
            }

            var errors = new List<string>();
            if (string.IsNullOrWhiteSpace(item) || item.Length < Options.RequiredLength)
            {
                errors.Add(String.Format(CultureInfo.CurrentCulture, Resources.PasswordTooShort, Options.RequiredLength));
            }
            if (Options.RequireNonLetterOrDigit && item.All(IsLetterOrDigit))
            {
                errors.Add(Resources.PasswordRequireNonLetterOrDigit);
            }
            if (Options.RequireDigit && item.All(c => !IsDigit(c)))
            {
                errors.Add(Resources.PasswordRequireDigit);
            }
            if (Options.RequireLowercase && item.All(c => !IsLower(c)))
            {
                errors.Add(Resources.PasswordRequireLower);
            }
            if (Options.RequireUppercase && item.All(c => !IsUpper(c)))
            {
                errors.Add(Resources.PasswordRequireUpper);
            }

            if (errors.Count == 0)
            {
                return Task.FromResult(ActionResult.Success);
            }
            else
            {
                return Task.FromResult(new ActionResult(errors.ToArray()));
            }
        }

        #endregion
    }
}
