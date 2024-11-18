using Maba.Hydra2.Systems.XCIGroup.DAL.DataAccessLayer.Models.Device;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device.Settings
{
    public class AlertSettingsView
    {
        public DeviceAlertSettingsView Device_Settings { set; get; }
        public DeviceAlertSettingsView Default_Settings { set; get; }

        public AlertSettingsView()
        {
                
        }
        public AlertSettingsView(AlertsSetting AlertsSetting, bool SendDefaults)
        {
            Device_Settings = new DeviceAlertSettingsView()
            {
                AlertCode = AlertsSetting.AlertCode,
                Name = AlertsSetting.Name,
                SN = AlertsSetting.SN,
                IsEnable = AlertsSetting.IsEnable.HasValue ? AlertsSetting.IsEnable.Value : AlertsSetting.Default_IsActive,
                SendEmail = AlertsSetting.SendEmail.HasValue ? AlertsSetting.SendEmail.Value : AlertsSetting.Default_SendEmail,
                SendSMS = AlertsSetting.SendSMS.HasValue ? AlertsSetting.SendSMS.Value : AlertsSetting.Default_SendSMS,
                Visible = AlertsSetting.Visible.HasValue ? AlertsSetting.Visible.Value : AlertsSetting.Default_Visible
            };

            if (SendDefaults)
            {
                Default_Settings = new DeviceAlertSettingsView()
                {
                    AlertCode = AlertsSetting.AlertCode,
                    Name = AlertsSetting.Name,
                    SN = AlertsSetting.SN,
                    IsEnable = AlertsSetting.Default_IsActive,
                    SendEmail = AlertsSetting.Default_SendEmail,
                    SendSMS = AlertsSetting.Default_SendSMS,
                    Visible = AlertsSetting.Default_Visible
                };
            }
        }
    }
}
