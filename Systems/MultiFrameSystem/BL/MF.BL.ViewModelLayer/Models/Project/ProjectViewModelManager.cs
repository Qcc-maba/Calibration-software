using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Project
{
    public class ProjectViewModelManager : Base.BaseViewModelManager
    {
        #region members

        private DAL.AdminLayer.Repositories.Foldering.IFolderingRepository _FolderingRepository = null;
        private DAL.AdminLayer.Repositories.Account.IAccountRepository _AccountRepository = null;

        #endregion

        #region ctor

        public ProjectViewModelManager(Base.ViewModelSettings currentSettings)
            : base(currentSettings)
        {
            _FolderingRepository = currentSettings.DAL_AdminLayer_RepositoriesGenerator.Generator_IFolderingRepository();
            _AccountRepository = currentSettings.DAL_AdminLayer_RepositoriesGenerator.Generator_IAccountRepository();
        }

        #endregion

        #region BaseViewModelManager members

        protected override void OnDispose()
        {
            if (_FolderingRepository != null)
            {
                this._FolderingRepository.Dispose();
            }
        }

        #endregion

        #region private methods

        private DAL.AdminLayer.Models.Project GetProjectEntity(long UserID, long ProjectID)
        {
            var ShareData = ValidateOwnership_Project(UserID, ProjectID);
            if (ShareData == null || ShareData.IsVerified == null && !ShareData.IsVerified.Value)
                throw new Exceptions.SecurityException();

            //get project
            var _project = _FolderingRepository.GetProject(ProjectID);
            if (_project == null)
                throw new Exceptions.ExpectedElementMissingException();

            return _project;
        }

        private void matchingParent(List<ProjectTreeContainerView> HierarchyRecords, ProjectTreeContainerView child)
        {
            foreach (var item in HierarchyRecords)
            {
                if (item.SiteID == child.ParentSiteID)
                {
                    if (item.Sites == null)
                    {
                        item.Sites = new List<ProjectTreeContainerView>();
                    }

                    item.Sites.Add(child);

                    return;
                }
                else if (item.Sites != null)
                {
                    matchingParent(item.Sites, child);
                }
            }
        }

        #endregion

        #region public methods

        public ExchangeView GetUserExchange(string Email)
        {
            var exchange = _AccountRepository.GetExchange_ByEmail(Email);

            return exchange == null ? null : new ExchangeView(exchange);
        }

        public ExchangeView MakeFirstExchangeProcess(User.UserView User, string lastToken)
        {
            var exchange = GetUserExchange(User.Email);

            if (exchange == null)
            {
                #region New User

                //for new users - we will create him in MF system
                var newUser = new DAL.AdminLayer.Models.AccountUser()
                {
                    ImgURL = User.ImgURL,
                    FirstName = User.FirstName,
                    LastName = User.LastName,
                    LastToken = lastToken,
                    CultureCode = User.CultureCode,
                    Email = User.Email,
                    Version = User.Version,
                    IdentityUserGUID = User.AccountUserGUID,
                    TimeZoneID = User.TimeZoneID
                };
                var userID = _AccountRepository.AddUser(newUser);

                //get exchange data for him (let the repository create default one)
                exchange = GetUserExchange(User.Email);

                #endregion
            }
            else
            {
                #region Exists user

                //delete this comment  - after implementing Token-Exchange
                //it's possible that same user already exists in different UserID.
                //let's make sure we are sync with UserID in both places

                //check if any changes were made in Account system
                if (User.Version != exchange.UpdateVersion)
                {
                    var updatedUser = new DAL.AdminLayer.Models.AccountUser()
                    {
                        ImgURL = User.ImgURL,
                        FirstName = User.FirstName,
                        LastName = User.LastName,
                        LastToken = lastToken,
                        CultureCode = User.CultureCode,
                        Email = User.Email,
                        Version = User.Version,
                        IdentityUserGUID = User.AccountUserGUID,
                        TimeZoneID = User.TimeZoneID,

                    };
                    exchange.UpdateVersion = updatedUser.Version;
                    _AccountRepository.UpdateUser(updatedUser);
                }

                #endregion
            }

            return exchange;
        }

        public ProjectView GetProject(long UserID, long ProjectID)
        {
            var _project = GetProjectEntity(UserID, ProjectID);

            return new ProjectView(_project);
        }

        public ProjectsTreeViewModel GetProjectsTree(long UserID, int PageNumber, int PageSize, string Search)
        {
            var sites = _FolderingRepository.GetTree(UserID, PageNumber, PageSize, Search: Search);

            var userExchange = _AccountRepository.GetExchange(UserID);

            var _projectsTree = new ProjectsTreeViewModel()
            {
                CurrentPageNumber = PageNumber,
                CurrentPageSize = PageSize,
                SearchText = Search,
                TotalProjects = userExchange.RootSiteCount,
                Projects = null
            };

            List<ProjectTreeContainerView> H_list = new List<ProjectTreeContainerView>();
            for (int i = 0; i < sites.CurrentPageItems.Length; i++)
            {
                var p_dal = sites.CurrentPageItems[i];

                var p = new Project.ProjectTreeContainerView()
                {
                    Name = p_dal.SiteName,
                    SiteID = p_dal.SiteID,
                    SharingData = new TreeNodeView(p_dal),
                    ParentSiteID = p_dal.ParentSiteID
                };

                if (p.ParentSiteID == null)
                {
                    H_list.Add(p);
                }
                else
                {
                    matchingParent(H_list, p);
                }
            };

            _projectsTree.Projects = H_list.ToArray();

            return _projectsTree;
        }

        public bool Test()
        {
            return _FolderingRepository.Test();
        }

        public ProjectsTreeViewModel GetProjectsTree(long UserID, long ProjectID, int PageSize)
        {
            var pageNumber = SearchProjectPageNumber(UserID, ProjectID, PageSize);

            if (pageNumber > 0)
            {
                return GetProjectsTree(UserID, pageNumber, PageSize, null);
            }
            else
            {
                return GetProjectsTree(UserID, 1, PageSize, null);
            }
        }

        public int SearchProjectPageNumber(long UserID, long ProjectID, int PageSize)
        {
            ValidateOwnership_Project(UserID, ProjectID);
            return _FolderingRepository.GetSitePageNumber(ProjectID, UserID, PageSize);
        }

        public ProjectListView[] GetProjects(long UserID)
        {
            var _project = _FolderingRepository.GetProjects(UserID);

            return _project
                .CurrentPageItems
                .Select(p => new ProjectListView(p))
                .ToArray();
        }

        public bool SaveProjectLocation(long UserID, long ProjectID, MapLocationView Location)
        {
            var ShareData = ValidateOwnership_Project(UserID, ProjectID);

            if (!ShareData.RoleModify)
                throw new Exceptions.SecurityException();

            var _locaion = new DAL.AdminLayer.Models.MapLocationData();
            Location.CopyToLocationDAL(_locaion);

            //update
            return _FolderingRepository.UpdateSiteLocation(ProjectID, _locaion);
        }

        public long CreateProject(long UserID, string ProjectName, MapLocationView Location)
        {
            #region create the project entity

            var newProject = new DAL.AdminLayer.Models.Project()
            {
                Name = ProjectName
            };

            if (Location != null)
            {
                Location.CopyToSite(newProject);
            }

            var newProjectID = _FolderingRepository.AddProject(newProject, UserID);

            #endregion

            return newProjectID;
        }

        public bool UpdateProject(long UserID, long ProjectID, string ProjectName)
        {
            var ShareData = ValidateOwnership_Project(UserID, ProjectID);
            if (ShareData == null || ShareData.IsVerified == null && !ShareData.IsVerified.Value)
                throw new Exceptions.SecurityException();

            return _FolderingRepository.UpdateProject(ProjectID, ProjectName);
        }

        public bool DeleteProject(long UserID, long ProjectID)
        {
            var ShareData = ValidateOwnership_Project(UserID, ProjectID);
            if (ShareData == null || ShareData.IsVerified == null && !ShareData.IsVerified.Value)
                throw new Exceptions.SecurityException();

            return _FolderingRepository.DeleteProject(ProjectID, UserID);
        }

        #region Alerts

        public ProjectAlertsView GetProjectsAlerts(long UserID, long ProjectID, bool IncludedSub, int PageNumber = 1, int PageSize = 10)
        {
            var node = ValidateOwnership_Project(UserID, ProjectID);

            var alert_respon = _FolderingRepository.DevicesAlerts_GetAll(ProjectID, UserID, IncludedSub, PageNumber, PageSize);

            var ProjectAlertView = new ProjectAlertsView()
            {
                ProjectID = ProjectID,
                ProjectName = node.SiteName != null ? node.SiteName : "",
                TotalItems = alert_respon != null ? alert_respon.TotalItems : 0,
                DeviceAlertsView = alert_respon != null ? alert_respon.CurrentPageItems.Select(u => new DeviceAlertInSiteView(u)).ToArray() : null
            };

            return ProjectAlertView;
        }

        public bool UpdateProjectAlerts(long UserID, UpdateProjectAlertsModel updateProjectAlertView)
        {
            var ShareData = ValidateOwnership_Project(UserID, updateProjectAlertView.ProjectID);

            if (!ShareData.RoleModify)
                throw new Exceptions.SecurityException();

            var result = true;

            foreach (var item in updateProjectAlertView.DeviceAlertsView)
            {
                var deviceValidation = ValidateOwnership_SN(UserID, item.SN);
                Validate_RoleModify(deviceValidation);
                result = _FolderingRepository.DevicesAlerts_UpdateUser(item.IsAlertsEnabled, deviceValidation.DeviceID, UserID);
                if (!result)
                    return result;
            }

            return result;
        }

        public bool UpdateMacroAlerts(long userID, long projectID, bool status, bool includedSub)
        {
            return _FolderingRepository.DevicesAlerts_UpdateMacro(userID, projectID, status, includedSub);
        }

        #endregion

        #endregion
    }
}