using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using OWINLibrary = Maba.Connectors.OWINLibrary;
namespace Maba.AccountSystem.AspNetIdentity.Identity2.Settings
{
    public class ManagerSettings
    {
        #region properties

        public Settings.SecuritySettings SecurityOptions { get; set; }
        public Settings.PasswordValidatorSettings PasswordValidatorOptions { get; set; }
        public Settings.UserValidatorSettings UserValidatorOptions { get; set; }
        public int AccessFailedCount_MaxAttempts { get; set; } = 5;
        public TimeSpan AccessFailedCount_BlockPeriod { get; set; } = TimeSpan.FromMinutes(15);

        #endregion

        #region ctor

        public ManagerSettings()
        {
            this.SecurityOptions = new Settings.SecuritySettings();
            this.PasswordValidatorOptions = new Settings.PasswordValidatorSettings();
            this.UserValidatorOptions = new Settings.UserValidatorSettings();
        }

        #endregion
    }
}
