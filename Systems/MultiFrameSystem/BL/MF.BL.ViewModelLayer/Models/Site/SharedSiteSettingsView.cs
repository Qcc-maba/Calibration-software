using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Site
{
    public class SharedSiteSettingsView
    {
        #region properties

        public long SiteID { get; set; }
        public SharingVerificationStatus VerificationStatus { get; set; }

        public bool RoleModify { get; set; }
        public bool RoleViewOnly { get; set; }

        public bool RoleControlRT { get; set; }
        public bool RoleAdmin { get; set; }
        public string Email { get; set; }

        #endregion

        #region ctor(s)

        public SharedSiteSettingsView()
        {

        }

        public SharedSiteSettingsView(DAL.AdminLayer.Models.User2Site site)
        {
            if (site == null)
                return;

            if (site.IsVerified == null)
            {
                VerificationStatus = SharingVerificationStatus.Pending;
            }
            else if (site.IsVerified.Value)
            {
                VerificationStatus = SharingVerificationStatus.Accepted;
            }
            else
            {
                VerificationStatus = SharingVerificationStatus.Rejected;
            }

            RoleControlRT = site.RoleControlRT;
            RoleModify = site.RoleModify;
            RoleAdmin = site.RoleAdmin;
            RoleViewOnly = site.RoleViewOnly;
            Email = site.Email;
            SiteID = site.SiteID;

        }

        /* public SharedSiteSettingsView(DAL.AdminLayer.Models.MainSiteShareData site)
         {
             if (site.IsVerified == null)
             {
                 VerificationStatus = SharingVerificationStatus.Pending;
             }
             else if (site.IsVerified.Value)
             {
                 VerificationStatus = SharingVerificationStatus.Accepted;
             }
             else
             {
                 VerificationStatus = SharingVerificationStatus.Rejected;
             }
             RoleControlRT = site.RoleControlRT;
             RoleModify = site.RoleModify;
             RoleAdmin = site.RoleAdmin;
         }*/

        #endregion
    }
}
