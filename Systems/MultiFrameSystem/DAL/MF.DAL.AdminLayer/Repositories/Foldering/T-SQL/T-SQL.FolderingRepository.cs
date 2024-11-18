using Maba.DAL.BaseDAL;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models;
using System.Data.SqlClient;
using Microsoft.SqlServer.Server;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories.Foldering.TSQL
{
    public class TSQLFolderingRepository : BaseConnector, IFolderingRepository
    {
        #region CONSTANTS

        public const string DEFAULT_STRING_CONNECTION = "MFSystemAdminDB";

        #endregion

        #region ctor(s)

        private void initCtor()
        {
        }

        public TSQLFolderingRepository()
            : base(DEFAULT_STRING_CONNECTION)
        {
            initCtor();
        }

        public TSQLFolderingRepository(string providerName, string stringConnection)
            : base(providerName, stringConnection)
        {
            initCtor();
        }

        public TSQLFolderingRepository(string stringConnectionSectionName)
            : base(stringConnectionSectionName)
        {
            initCtor();
        }

        #endregion

        #region Implementation of IFolderingRepository

        public bool Test()
        {
            bool Result = false;
            int rowsAffected = 0;
            var result32 = Connector.GetProcedureResultInt32("Test",
                                                                     new IDataParameter[] {
                                                                      Connector.CreateParameter("Test",1)
                                                                    }, out rowsAffected, out Result);

            return Result && result32 > 0;
        }

        #region Project

        #region Tree

        public AdminLayer.Models.TreePagedResponse GetTree(long UserID, int PageNumber = 1, int PageSize = 100, long? FilterSiteID = null, int? LimitLevel = null, string Search = null)
        {
            var TotalItemsResult = Connector.CreateParameter("TotalProjects", -1);
            TotalItemsResult.Direction = ParameterDirection.Output;
            Search = string.IsNullOrEmpty(Search) ? null : Search;

            var items = Connector.GetEntities<AdminLayer.Models.TreeNode>(this.Connector.CreateProcedureEnumerator("Tree.GetUserTree_Details",
                                                                     new IDataParameter[] {
                                                                      Connector.CreateParameter("UserID",UserID),
                                                                      Connector.CreateParameter("Search",Search),
                                                                      Connector.CreateParameter("PageNumber",PageNumber),
                                                                      Connector.CreateParameter("PageSize",PageSize),
                                                                      Connector.CreateParameter("LimitLevel",LimitLevel),
                                                                      Connector.CreateParameter("FilterSiteID",FilterSiteID),
                                                                      TotalItemsResult
                                                                    }))
                                                                    .ToArray();


            var response = new AdminLayer.Models.TreePagedResponse()
            {
                CurrentPageItems = items,
                CurrentPageNumber = PageNumber,
                CurrentPageSize = PageSize,
            };

            if (FilterSiteID.HasValue)
            {
                //when filtering to particular site, we can get at most one project.
                //so, number of projects depends on items.Length (when no result -> no project)
                response.TotalProjects = items.Length > 0 ? 1 : 0;
            }
            else
            {
                response.TotalProjects = (DBNull.Value != TotalItemsResult.Value && TotalItemsResult.Value != null) ? (int)TotalItemsResult.Value : 0;
            }

            return response;
        }

        public int GetSitePageNumber(long SiteID, long UserID, int PageSize)
        {
            bool Result = false;
            int rowsAffected = 0;
            return Connector.GetProcedureResultInt32("Tree.GetProjectPageNumber",
                                                                     new IDataParameter[] {
                                                                      Connector.CreateParameter("UserID",UserID),
                                                                      Connector.CreateParameter("SiteID",SiteID),
                                                                      Connector.CreateParameter("PageSize",PageSize)
                                                                    }, out rowsAffected, out Result);
        }

        #endregion

        public AdminLayer.Models.Project GetProject(long ProjectID)
        {
            return Connector.GetEntity<AdminLayer.Models.Project>(this.Connector.CreateProcedureEnumerator("Site.GetProject",
                                                            new IDataParameter[] {
                                                                        Connector.CreateParameter("ProjectID",ProjectID)}));
        }

        public long AddProject(AdminLayer.Models.MainSite newProject, long UserID)
        {
            bool Result = false;
            int rowsAffected = 0;
            newProject.SiteID = Connector.GetProcedureResultInt64("Site.AddProject", new IDataParameter[] {
                                                                        Connector.CreateParameter("Name",newProject.Name),
                                                                        Connector.CreateParameter("UserID", UserID),
                                                                        Connector.CreateParameter("MapCenter_AutoBounds",newProject.MapCenter_AutoBounds),
                                                                        Connector.CreateParameter("MapCenter_Latitude",newProject.MapCenter_Latitude),
                                                                        Connector.CreateParameter("MapCenter_Longitude",newProject.MapCenter_Longitude),
                                                                        Connector.CreateParameter("MapCenter_Mode",newProject.MapCenter_Mode),
                                                                        Connector.CreateParameter("MapCenter_Zoom",newProject.MapCenter_Zoom),

                                                                    }, out rowsAffected, out Result);

            return newProject.SiteID;
        }

        public AdminLayer.Models.TreeNode ValidateOwnership_Project(long UserID, long ProjectID)
        {
            return this.ValidateOwnership_Site(UserID, ProjectID);
        }

        public AdminLayer.Models.Common.PagedResponse<AdminLayer.Models.ProjectTitle> GetProjects(long UserID, string Search = null, int? PageNumber = null, int? PageSize = null)
        {
            var TotalItemsResult = Connector.CreateParameter("TotalItems", -1);
            TotalItemsResult.Direction = ParameterDirection.Output;
            Search = string.IsNullOrEmpty(Search) ? null : Search;

            var items = Connector.GetEntities<AdminLayer.Models.ProjectTitle>(this.Connector.CreateProcedureEnumerator("Site.GetProjects",
                                                            new IDataParameter[] {
                                                                         Connector.CreateParameter("UserID",UserID),
                                                                         Connector.CreateParameter("PageNumber",PageNumber),
                                                                         Connector.CreateParameter("PageSize",PageSize),
                                                                         Connector.CreateParameter("Search",Search),
                                                                         TotalItemsResult}))
                                                             .ToArray();

            if (PageNumber.HasValue && PageSize.HasValue)
            {
                return new AdminLayer.Models.Common.PagedResponse<AdminLayer.Models.ProjectTitle>()
                {
                    CurrentPageItems = items,
                    TotalItems = (DBNull.Value != TotalItemsResult.Value && TotalItemsResult.Value != null) ? (int)TotalItemsResult.Value : 0,
                    CurrentPageNumber = PageNumber.Value,
                    CurrentPageSize = PageSize.Value,
                };
            }
            else
            {
                return new AdminLayer.Models.Common.PagedResponse<AdminLayer.Models.ProjectTitle>()
                {
                    CurrentPageItems = items,
                    TotalItems = items.Length,
                    CurrentPageNumber = 1,
                    CurrentPageSize = items.Length,
                };
            }
        }

        public bool UpdateProject(long projectID, string projectName)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("Site.UpdateProject", new IDataParameter[] {
                                                                        Connector.CreateParameter("Name",projectName),
                                                                        Connector.CreateParameter("ProjectID",projectID)
                                                                    }, out rowsAffected, out Result);
            return Result;
        }

        public bool DeleteProject(long ProjectID, long UserID)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("Site.DeleteProject", new IDataParameter[] {
                                                                      Connector.CreateParameter("ProjectID",ProjectID),
                                                                      Connector.CreateParameter("SourceUserID",UserID)
                                                                    }, out rowsAffected, out Result);
            return Result;
        }

        #endregion

        #region Site

        #region Sharing site management
        public bool ShareSite_Accept(long SourceSiteID, long TargetUserID, long? TargetSiteID)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt64("Site.SharedUsers_Accept", new IDataParameter[] {
                                                                        Connector.CreateParameter("SourceSiteID",SourceSiteID),
                                                                        Connector.CreateParameter("TargetUserID",TargetUserID),
                                                                         Connector.CreateParameter("TargetSiteID",TargetSiteID)
                                                                    }, out rowsAffected, out Result);

            return Result;
        }

        public AdminLayer.Models.User2Site[] SharedUsers_GetAll(long SiteID)
        {
            return Connector.GetEntities<AdminLayer.Models.User2Site>(this.Connector.CreateProcedureEnumerator("Site.SharedUsers_GetAll",
                                                           new IDataParameter[] {
                                                                        Connector.CreateParameter("SiteID",SiteID)
                                                                        })).ToArray();
        }

        public bool SharedUsers_Update(long SourceUserID, AdminLayer.Models.User2Site User2Site)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("Site.SharedUsers_Update", new IDataParameter[] {
                                                                        Connector.CreateParameter("SourceUserID",SourceUserID),
                                                                        Connector.CreateParameter("SourceSiteID",User2Site.SiteID),
                                                                        Connector.CreateParameter("RoleAdmin",User2Site.RoleAdmin),
                                                                        Connector.CreateParameter("RoleControlRT",User2Site.RoleControlRT),
                                                                        Connector.CreateParameter("RoleModify",User2Site.RoleModify),
                                                                        Connector.CreateParameter("RoleViewOnly",User2Site.RoleViewOnly),
                                                                        Connector.CreateParameter("TargetUserID",User2Site.LinkedUserID)
                                                                    }, out rowsAffected, out Result);
            return Result;
        }

        public bool SharedUsers_Delete(long SourceSiteID, long SourceUserID, long TargetUserID_2Delete)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("Site.SharedUsers_Delete", new IDataParameter[] {
                                                                        Connector.CreateParameter("SourceSiteID",SourceSiteID),
                                                                        Connector.CreateParameter("SourceUserID",SourceUserID),
                                                                        Connector.CreateParameter("TargetUserID",TargetUserID_2Delete),
                                                                    }, out rowsAffected, out Result);
            return Result;
        }

        public bool SharedUsers_Reject(long SourceSiteID, long ActionUserID, long TargetUserID)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("Site.SharedUsers_Reject", new IDataParameter[] {
                                                                        Connector.CreateParameter("SourceSiteID",SourceSiteID),
                                                                        Connector.CreateParameter("TargetUserID",TargetUserID),
                                                                        Connector.CreateParameter("ActionUserID",ActionUserID),

                                                                    }, out rowsAffected, out Result);
            return Result;
        }

        public bool SharedUsers_Add(long SourceUserID, AdminLayer.Models.User2Site User2Site, out bool? ProccessComplete)
        {
            var IsComplete = Connector.CreateOutParameter("IsComplete", false);

            var Result = false;
            int rowsAffected = 0;

            long linkID = Connector.GetProcedureResultInt64("Site.SharedUsers_Add", new IDataParameter[] {
                                                                        Connector.CreateParameter("SourceSiteID",User2Site.SiteID),
                                                                        Connector.CreateParameter("SourceUserID",SourceUserID),
                                                                        Connector.CreateParameter("TargetUserID",User2Site.LinkedUserID==-1 ? null : (long?)User2Site.LinkedUserID),
                                                                        Connector.CreateParameter("Email",User2Site.Email),


                                                                        Connector.CreateParameter("RoleAdmin",User2Site.RoleAdmin),
                                                                        Connector.CreateParameter("RoleControlRT",User2Site.RoleControlRT),
                                                                        Connector.CreateParameter("RoleModify",User2Site.RoleModify),
                                                                        Connector.CreateParameter("RoleViewOnly",User2Site.RoleViewOnly),
                                                                        IsComplete

                                                                    }, out rowsAffected, out Result);

            ProccessComplete = DBNull.Value != IsComplete.Value ? (bool?)IsComplete.Value : null;

            if (Result && ProccessComplete.HasValue)
            {
                User2Site.LinkID = linkID;
            }
            else
            {
                User2Site.LinkID = -1;
            }
            //CheckExceptions();
            return Result;
        }

        #endregion

        #region Transferring site management

        public bool SiteTransfer_Accept(long SourceSiteID, long SourceUserID, long? TargetSiteID, long TargetUserID)
        {
            var Result = false;
            int rowsAffected = 0;

            var PathParamater = Connector.CreateOutParameter("Path", "");

            Connector.GetProcedureResultInt64("Site.Transfer_Accept", new IDataParameter[] {
                                                                        Connector.CreateParameter("SourceSiteID",SourceSiteID),
                                                                        Connector.CreateParameter("TargetSiteID", TargetSiteID),
                                                                        Connector.CreateParameter("SourceUserID",SourceUserID),
                                                                        Connector.CreateParameter("TargetUserID",TargetUserID),
                                                                        PathParamater
                                                                    }, out rowsAffected, out Result);
            //CheckExceptions();
            return Result;
        }

        public bool SiteTransfer_Start(AdminLayer.Models.NewTransferSiteRequest newTransfer)
        {
            var Result = false;
            int rowsAffected = 0;

            Connector.GetProcedureResultInt64("Site.Transfer_Start", new IDataParameter[] {
                                                                        Connector.CreateParameter("SiteID",newTransfer.SiteID),
                                                                        Connector.CreateParameter("SourceUserID",newTransfer.SourceUserID),
                                                                        Connector.CreateParameter("TargetUserID",newTransfer.TargetUserID),
                                                                        Connector.CreateParameter("MessageID",newTransfer.MessageID)
                                                                    }, out rowsAffected, out Result);

            //CheckExceptions();
            return Result;
        }

        public bool SiteTransfer_Cancel(long SourceUserID, long SourceSiteID)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("Site.Transfer_Cancel", new IDataParameter[] {
                                                                        Connector.CreateParameter("SourceSiteID",SourceSiteID),
                                                                        Connector.CreateParameter("SourceUserID",SourceUserID)
                                                                    }, out rowsAffected, out Result);
            return Result;
        }

        public bool SiteTransfer_Reject(long SourceUserID, long TargetUserID, long SiteID)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("Site.Transfer_Reject", new IDataParameter[] {
                                                                        Connector.CreateParameter("SiteID",SiteID),
                                                                        Connector.CreateParameter("SourceUserID",SourceUserID),
                                                                        Connector.CreateParameter("TargetUserID",TargetUserID)
                                                                    }, out rowsAffected, out Result);
            return Result;

        }

        public AdminLayer.Models.TransferSite[] SiteTransfer_GetAllPendings(long SiteID, long? SourceUserID)
        {
            return Connector.GetEntities<AdminLayer.Models.TransferSite>(this.Connector.CreateProcedureEnumerator("Site.Transfer_GetAllPendings",
                                                                     new IDataParameter[] {
                                                                        Connector.CreateParameter("SiteID",SiteID),
                                                                        Connector.CreateParameter("SourceUserID",SourceUserID)
                                                                    }))
                                                                    .ToArray();
        }

        public bool LocalTransfer(long UserID, long SourceSiteID, long TargetSite)
        {
            var Result = false;
            int rowsAffected = 0;
            var PathParamater = Connector.CreateOutParameter("Path", "");

            Connector.GetProcedureResultInt32("Site.LocalTransfer", new IDataParameter[] {
                                                                        Connector.CreateParameter("SourceUserID",UserID),
                                                                        Connector.CreateParameter("SourceSiteID", SourceSiteID),
                                                                        Connector.CreateParameter("TargetSiteID", TargetSite),
                                                                        PathParamater
                                                                    }, out rowsAffected, out Result);
            return Result;
        }

        #endregion

        #region Devices

        public UserToDevice[] GetDevicesSubscribed(long UserID)
        {
            return Connector.GetEntities<AdminLayer.Models.UserToDevice>(this.Connector.CreateProcedureEnumerator("Account.GetDevicesSubscribed",
                                                            new IDataParameter[] {
                                                                        Connector.CreateParameter("UserID", UserID)

                                                                        })).ToArray();
        }

        #endregion

        #region Users

        /*public AdminLayer.Models.User2Site[] GetUpmostUsers(long SiteID)
        {
            return Connector.GetEntities<AdminLayer.Models.User2Site>(this.Connector.CreateProcedureEnumerator("Tree.GetUpmostUsers_Details",
                                                           new IDataParameter[] {
                                                                        Connector.CreateParameter("SiteID",SiteID)})).ToArray();
        }*/

        #endregion

        public AdminLayer.Models.MapLocationData GetSiteLocation(long SiteID)
        {
            return Connector.GetEntity<AdminLayer.Models.MapLocationData>(this.Connector.CreateProcedureEnumerator("Site.GetSiteLocation",
                                                            new IDataParameter[] {
                                                                        Connector.CreateParameter("SiteID",SiteID)}));
        }

        public AdminLayer.Models.SiteInfo GetSiteInfo(long UserID, long SiteID)
        {
            var S = Connector.GetEntity<AdminLayer.Models.SiteInfo>(this.Connector.CreateProcedureEnumerator("Site.GetSiteInfo",
                                                                     new IDataParameter[] {
                                                                        Connector.CreateParameter("SiteID",SiteID),
                                                                        Connector.CreateParameter("UserID",UserID)
                                                        }));

            return S;
        }

        public AdminLayer.Models.TreeNode ValidateOwnership_Site(long UserID, long SiteID)
        {
            var val = Connector.GetEntity<AdminLayer.Models.TreeNode>(this.Connector.CreateProcedureEnumerator("Site.ValidateOwnership_Site",
                                                                     new IDataParameter[] {
                                                                        Connector.CreateParameter("UserID",UserID),
                                                                        Connector.CreateParameter("SiteID",SiteID)
                                                                    }));

            return val;
        }

        public long AddSite(long UserID, AdminLayer.Models.MainSite newSite)
        {
            bool Result = false;
            int rowsAffected = 0;
            newSite.SiteID = Connector.GetProcedureResultInt64("Site.AddSite", new IDataParameter[] {
                                                                        Connector.CreateParameter("Name",newSite.Name),
                                                                        Connector.CreateParameter("MapCenter_AutoBounds",newSite.MapCenter_AutoBounds),
                                                                        Connector.CreateParameter("MapCenter_Latitude",newSite.MapCenter_Latitude),
                                                                        Connector.CreateParameter("MapCenter_Longitude",newSite.MapCenter_Longitude),
                                                                        Connector.CreateParameter("MapCenter_Mode",newSite.MapCenter_Mode),
                                                                        Connector.CreateParameter("MapCenter_Zoom",newSite.MapCenter_Zoom),
                                                                        Connector.CreateParameter("ParentSiteID",newSite.ParentSiteID),
                                                                        Connector.CreateParameter("UserID",UserID),
                                                                    }, out rowsAffected, out Result);
            return newSite.SiteID;
        }

        public AdminLayer.Models.MainSite GetSite(long siteID)
        {
            return Connector.GetEntity<AdminLayer.Models.MainSite>(this.Connector.CreateProcedureEnumerator("Site.GetSite",
                                                            new IDataParameter[] {
                                                                        Connector.CreateParameter("SiteID",siteID)}));
        }

        public bool UpdateSite(long SiteID, string SiteName)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("Site.UpdateSite", new IDataParameter[] {
                                                                        Connector.CreateParameter("Name",SiteName),
                                                                        Connector.CreateParameter("SiteID",SiteID)
                                                                    }, out rowsAffected, out Result);
            return Result;
        }

        public bool DeleteSite(long SiteID, long UserID)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("Site.DeleteSite", new IDataParameter[] {
                                                                      Connector.CreateParameter("SourceSiteID",SiteID),
                                                                      Connector.CreateParameter("SourceUserID",UserID)
                                                                    }, out rowsAffected, out Result);
            return Result;
        }

        public bool UpdateSiteLocation(long siteID, AdminLayer.Models.MapLocationData mapLocationData)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("Site.UpdateSiteLocation",
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("SiteID",siteID),
                                                                        Connector.CreateParameter("MapCenter_AutoBounds",mapLocationData.MapCenter_AutoBounds),
                                                                        Connector.CreateParameter("MapCenter_Latitude",mapLocationData.MapCenter_Latitude),
                                                                        Connector.CreateParameter("MapCenter_Longitude",mapLocationData.MapCenter_Longitude),
                                                                        Connector.CreateParameter("MapCenter_Mode",mapLocationData.MapCenter_Mode),
                                                                        Connector.CreateParameter("MapCenter_Zoom",mapLocationData.MapCenter_Zoom)},
                                                                        out rowsAffected,
                                                                        out Result);

            return Result;
        }

        public bool SaveDeviceLocation(string SN, string Latitude, string Longitude)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("Device.UpdateLocation",
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("SN", SN),
                                                                        Connector.CreateParameter("Lat", Latitude),
                                                                        Connector.CreateParameter("Lon", Longitude)}
                                                                       ,
                                                                        out rowsAffected,
                                                                        out Result);

            return Result;
        }

        public AdminLayer.Models.DeviceInfoWithParent[] GetUserTreeDevices(long SiteID, long UserID)
        {
            return Connector.GetEntities<AdminLayer.Models.DeviceInfoWithParent>(this.Connector.CreateProcedureEnumerator("Tree.GetUserTreeDevices_Details",
                                                            new IDataParameter[] {
                                                                        Connector.CreateParameter("SiteID",SiteID),
                                                                        Connector.CreateParameter("UserID",UserID)

                                                                        })).ToArray();
        }

        public AdminLayer.Models.MainDevice[] GetSiteDirectDevices(long SiteID)
        {
            return Connector.GetEntities<AdminLayer.Models.MainDevice>(this.Connector.CreateProcedureEnumerator("Site.GetDirectDevices",
                                                            new IDataParameter[] {
                                                                        Connector.CreateParameter("SiteID",SiteID)

                                                                        })).ToArray();
        }

        #region Session

        public bool DeleteSessionSetting(long sessionID)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("Site.DeleteSessionSetting", new IDataParameter[] {
                                                                      Connector.CreateParameter("SessionID",sessionID)
                                                                    }, out rowsAffected, out Result);
            return Result;
        }

        public bool UpdateSiteSessionTimeDay(long sessionID, long siteID, byte day, int time, bool allow)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("Site.UpdateSiteSessionTimeDay",
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("SessionID",sessionID),
                                                                        Connector.CreateParameter("SiteID",siteID),
                                                                        Connector.CreateParameter("DayIndex",day),
                                                                        Connector.CreateParameter("Time",time),
                                                                        Connector.CreateParameter("Allow",allow) },
                                                                        out rowsAffected,
                                                                        out Result);

            return Result;
        }

        public bool UpdateSessionSetting(Models.SessionSetting item)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("Site.UpdateSessionSetting", new IDataParameter[] {
                                                                    Connector.CreateParameter("EndDate",item.EndDate),
                                                                    Connector.CreateParameter("EraID",item.EraID),
                                                                    Connector.CreateParameter("IsAutoUpdate",item.IsAutoUpdate),
                                                                    Connector.CreateParameter("IsIrrigationAllowed",item.IsIrrigationAllowed),
                                                                    Connector.CreateParameter("Name",item.Name),
                                                                    Connector.CreateParameter("RestrictionType",item.RestrictionType),
                                                                    Connector.CreateParameter("SessionID",item.SessionID),
                                                                    Connector.CreateParameter("SessionIndex",item.SessionIndex),
                                                                    Connector.CreateParameter("SiteID",item.SiteID),
                                                                    Connector.CreateParameter("StartDate",item.StartDate)
                                                                    }, out rowsAffected, out Result);
            return Result;
        }

        public Models.SessionSetting[] GetSiteSessionSetting(long siteID)
        {
            return Connector.GetEntities<AdminLayer.Models.SessionSetting>(this.Connector.CreateProcedureEnumerator("Site.GetSessionSetting",
                                                                     new IDataParameter[] {
                                                                      Connector.CreateParameter("siteID",siteID)
                                                                     })).ToArray();
        }

        public Models.SessionDaySetting[] GetSessionDaySetting(long sessionID, long siteID, out string SessionName)
        {
            var a = Connector.GetEntities<AdminLayer.Models.SessionDaySetting>(this.Connector.CreateProcedureEnumerator("Site.GetSessionDaySetting",
                                                                     new IDataParameter[] {
                                                                      Connector.CreateParameter("SiteID",siteID),
                                                                      Connector.CreateParameter("SessionID",sessionID)
                                                                     })).ToArray();

            SessionName = GetSiteSessionSetting(siteID).FirstOrDefault(S => S.SessionID == sessionID).Name;
            return a;
        }

        private static IEnumerable<SqlDataRecord> CreateSqlMetaDataItem(TimeValueItem[] items)
        {
            SqlMetaData[] metaData = new SqlMetaData[2];
            metaData[0] = new SqlMetaData("Allow", SqlDbType.Bit);
            metaData[1] = new SqlMetaData("Time", SqlDbType.Int);

            return items
                .Select(r =>
                {
                    var record = new SqlDataRecord(metaData);
                    record.SetBoolean(0, r.Allow);
                    record.SetInt32(1, r.Time);
                    return record;
                });
        }

        public bool UpdateSiteSessionDay(long sessionID, long siteID, AdminLayer.Models.SessionDaySetting sessionDaySetting, TimeValueItem[] items)
        {
            var Result = false;
            int rowsAffected = 0;
            var Parameter = Connector.CreateParameter("Items", CreateSqlMetaDataItem(items)) as SqlParameter;
            Parameter.SqlDbType = SqlDbType.Structured;
            Parameter.TypeName = "Site.TimeValue";
            Connector.GetProcedureResultInt32("Site.UpdateSiteSessionDay", new IDataParameter[] {
                                                                       Connector.CreateParameter("DayIndex",sessionDaySetting.DayIndex),
                                                                       Connector.CreateParameter("MaxDailyCycles",sessionDaySetting.MaxDailyCycles),
                                                                       Connector.CreateParameter("MaxDailyIrrigrationSeconds",sessionDaySetting.MaxDailyIrrigrationSeconds),
                                                                       Connector.CreateParameter("Name",sessionDaySetting.Name),
                                                                       Connector.CreateParameter("ParentSessionID",sessionID),
                                                                       Connector.CreateParameter("SiteID",siteID),
                                                                       Parameter
                                                                    }, out rowsAffected, out Result);


            return Result;
        }

        #endregion

        #endregion

        #region Alerts
        public Models.Common.PagedResponse<Models.DeviceAlertSettings_2Site> DevicesAlerts_GetAll(long ProjectID, long UserID, bool IncludedSub, int PageNumber, int PageSize)
        {
            var TotalItemsResult = Connector.CreateParameter("TotalItems", -1);
            TotalItemsResult.Direction = ParameterDirection.Output;

            var items = Connector.GetEntities<AdminLayer.Models.DeviceAlertSettings_2Site>(this.Connector.CreateProcedureEnumerator("Site.DevicesAlerts_GetAll",
                                                                    new IDataParameter[] {
                                                                        Connector.CreateParameter("UserID",UserID),
                                                                        Connector.CreateParameter("ProjectID",ProjectID),
                                                                        Connector.CreateParameter("SubDevices",IncludedSub),
                                                                        Connector.CreateParameter("PageSize",PageSize),
                                                                        Connector.CreateParameter("PageNumber",PageNumber),
                                                                        TotalItemsResult
                                                                    }))
                                                                    .ToArray();

            var reponse = new Models.Common.PagedResponse<Models.DeviceAlertSettings_2Site>()
            {
                CurrentPageItems = items,
                CurrentPageNumber = PageNumber,
                CurrentPageSize = PageSize,
                TotalItems = (DBNull.Value != TotalItemsResult.Value && TotalItemsResult.Value != null) ? (int)TotalItemsResult.Value : 0
            };

            return reponse;
        }

        public bool DevicesAlerts_UpdateMacro(long userID, long projectID, bool status, bool includedSub)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("Site.DevicesAlerts_UpdateMacro", //UpdateMacroAlerts
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("ProjectID",projectID),
                                                                        Connector.CreateParameter("UserID",userID),
                                                                        Connector.CreateParameter("Status",status),
                                                                        Connector.CreateParameter("IncludedSub",includedSub)}
                                                                       ,
                                                                        out rowsAffected,
                                                                        out Result);

            return Result;
        }

        public bool DevicesAlerts_UpdateUser(bool isAlertsEnabled, long deviceID, long userID)
        {
            var Result = false;
            int rowsAffected = 0;
            Connector.GetProcedureResultInt32("Device.DevicesAlerts_UpdateUser", //UpdateActiveAlertInUser
                                                          new IDataParameter[] {
                                                                        Connector.CreateParameter("IsEnabled",isAlertsEnabled),
                                                                        Connector.CreateParameter("DeviceID",deviceID),
                                                                        Connector.CreateParameter("UserID",userID)}
                                                                       ,
                                                                        out rowsAffected,
                                                                        out Result);

            return Result;
        }

        #endregion

        #endregion

        #region OLD
        /*
        public AdminLayer.Models.MainSite[] GetSubTree(long SiteID)
        {
            return Connector.GetEntities<AdminLayer.Models.MainSite>(this.Connector.CreateProcedureEnumerator("Tree.GetSubTree_Details",
                                                                     new IDataParameter[] {
                                                                      Connector.CreateParameter("SiteID",SiteID)
                                                                        })).ToArray();

        }

        */

        #endregion
    }
}
