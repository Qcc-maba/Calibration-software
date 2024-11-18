using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories.Foldering
{
    public interface IFolderingRepository : IDisposable
    {
        bool Test();

        #region Project

        #region Tree

        AdminLayer.Models.TreePagedResponse GetTree(long UserID, int PageNumber = 1, int PageSize = 100, long? FilterSiteID = null, int? LimitLevel = null, string Search = null);
        int GetSitePageNumber(long SiteID, long UserID, int PageSize);

        #endregion

        AdminLayer.Models.Project GetProject(long ProjectID);
        long AddProject(AdminLayer.Models.MainSite site, long UserID);
        bool DeleteProject(long ProjectID, long UserID);
        AdminLayer.Models.TreeNode ValidateOwnership_Project(long UserID, long ProjectID);
        AdminLayer.Models.Common.PagedResponse<AdminLayer.Models.ProjectTitle> GetProjects(long UserID, string Search = null, int? PageNumber = null, int? PageSize = null);
        bool UpdateProject(long projectID, string projectName);

        #endregion

        #region Site

        #region Sharing

        AdminLayer.Models.User2Site[] SharedUsers_GetAll(long SiteID);

        bool SharedUsers_Add(long SourceUserID, AdminLayer.Models.User2Site User2Site, out bool? ProccessComplete);

        bool ShareSite_Accept(long SourceSiteID, long TargetUserID, long? TargetSiteID);

        bool SharedUsers_Delete(long SourceSiteID, long SourceUserID, long TargetUserID_2Delete);

        bool SharedUsers_Update(long SourceUserID, AdminLayer.Models.User2Site User2Site);

        bool SharedUsers_Reject(long SourceSiteID, long ActionUserID, long TargetUserID);

        #endregion

        #region Transfer

        AdminLayer.Models.TransferSite[] SiteTransfer_GetAllPendings(long SiteID, long? SourceUserID);

        bool SiteTransfer_Start(AdminLayer.Models.NewTransferSiteRequest newTransfer);
        bool SiteTransfer_Cancel(long SourceUserID, long SourceSiteID);
        bool SiteTransfer_Reject(long SourceUserID, long TargetUserID, long SiteID);

        bool SiteTransfer_Accept(long SourceSiteID, long SourceUserID, long? TargetSiteID, long TargetUserID);

        bool LocalTransfer(long UserID, long SourceSiteID, long TargetSite);

        #endregion

        #region Devices

        Models.UserToDevice[] GetDevicesSubscribed(long UserID);

        #endregion

        #region Users
        //AdminLayer.Models.User2Site[] GetUpmostUsers(long SiteID);

        #endregion

        #region Session

        bool DeleteSessionSetting(long sessionID);

        bool UpdateSiteSessionTimeDay(long sessionID, long siteID, byte day, int time, bool allow);

        bool UpdateSessionSetting(AdminLayer.Models.SessionSetting item);

        Models.SessionSetting[] GetSiteSessionSetting(long siteID);

        Models.SessionDaySetting[] GetSessionDaySetting(long sessionID, long siteID, out string SessionName);

        bool UpdateSiteSessionDay(long sessionID, long siteID, AdminLayer.Models.SessionDaySetting sessionDaySetting, Models.TimeValueItem[] items);

        #endregion

        AdminLayer.Models.MapLocationData GetSiteLocation(long SiteID);
        AdminLayer.Models.SiteInfo GetSiteInfo(long UserID, long SiteID);
        AdminLayer.Models.TreeNode ValidateOwnership_Site(long UserID, long SiteID);
        long AddSite(long UserID, AdminLayer.Models.MainSite newSite);
        AdminLayer.Models.MainSite GetSite(long siteID);
        bool UpdateSite(long SiteID, string SiteName);
        bool DeleteSite(long SiteID, long UserID);

        bool SaveDeviceLocation(string SN, string Latitude, string Longitude);
        AdminLayer.Models.MainDevice[] GetSiteDirectDevices(long SiteID);
        AdminLayer.Models.DeviceInfoWithParent[] GetUserTreeDevices(long SiteID, long UserID);

        bool UpdateSiteLocation(long SiteID, AdminLayer.Models.MapLocationData mapLocationData);

        #endregion

        #region Alerts
        Models.Common.PagedResponse<Models.DeviceAlertSettings_2Site> DevicesAlerts_GetAll(long ProjectID, long UserID, bool IncludedSub, int PageNumber, int PageSize);
        bool DevicesAlerts_UpdateMacro(long userID, long projectID, bool status, bool includedSub);
        bool DevicesAlerts_UpdateUser(bool isAlertsEnabled, long deviceID, long userID);
        #endregion

        #region Session


        #endregion

        #region OLD
        /*

        AdminLayer.Models.MainSite[] GetSubTree(long SiteID);

        */

        #endregion
    }
}
