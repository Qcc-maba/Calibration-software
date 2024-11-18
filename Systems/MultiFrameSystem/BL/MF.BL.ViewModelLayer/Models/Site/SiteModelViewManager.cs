using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Site
{
    public class SiteModelViewManager : Base.BaseViewModelManager
    {
        #region members

        private DAL.AdminLayer.Repositories.Foldering.IFolderingRepository _FolderingRepository = null;

        #endregion

        #region ctor

        public SiteModelViewManager(Base.ViewModelSettings currentSettings)
            : base(currentSettings)
        {
            _FolderingRepository = currentSettings.DAL_AdminLayer_RepositoriesGenerator.Generator_IFolderingRepository();
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
        /// <summary>
        /// When target user makes an action of Share-Transfer (like Accpet or Reject)
        /// We need more information about the source user and SiteID.
        /// Using this method - we get the information.
        /// </summary>
        private User.Messages.BodyView.FolderingBodyView _GetShareData(string UserEmail, string MessageID)
        {
            User.Messages.InboxMessageRecordView _message = null;
            using (var userManager = new User.UserViewModelManager(this.CurrentSettings))
            {
                _message = userManager.GetMessage(UserEmail, MessageID);
            }

            if (_message != null)
            {
                return _message.Body as User.Messages.BodyView.FolderingBodyView;
            }

            return null;
        }

        private User.Messages.MessageUserInfoView BuildUserInfo(long UserID)
        {
            DAL.AdminLayer.Models.AccountUser _user = null;
            using (var accountRepository = this.CurrentSettings.DAL_AdminLayer_RepositoriesGenerator.Generator_IAccountRepository())
            {
                _user = accountRepository.GetUser(UserID);
            }
            return new User.Messages.MessageUserInfoView(_user);
        }
        private User.Messages.MessageUserInfoView BuildUserInfo(string UserEmail)
        {
            DAL.AdminLayer.Models.AccountUser _user = null;
            using (var accountRepository = this.CurrentSettings.DAL_AdminLayer_RepositoriesGenerator.Generator_IAccountRepository())
            {
                _user = accountRepository.GetUser(UserEmail);
            }
            return new User.Messages.MessageUserInfoView(_user);
        }

        #endregion

        #region public methods

        public DAL.AdminLayer.Models.MainSite GetSiteEntity(long UserID, long SiteID)
        {
            var data = ValidateOwnership_Site(UserID, SiteID);
            Validate_RoleView(data);

            //get site
            var _site = _FolderingRepository.GetSite(SiteID);
            if (_site == null)
                throw new Exceptions.ExpectedElementMissingException();

            return _site;
        }

        public Site.SiteView GetSite(long UserID, long SiteID)
        {
            var nodeData = ValidateOwnership_Site(UserID, SiteID);

            var _site = _FolderingRepository.GetSite(SiteID);
            var siteInfo = new Site.SiteView(_site)
            {
                SharingData = new TreeNodeView(nodeData)
            };

            return siteInfo;
        }

        public long CreateSite(long UserID, string SiteName, long ParentProjectID, MapLocationView Location)
        {
            var newSite = new DAL.AdminLayer.Models.MainSite()
            {
                Name = SiteName,
                ParentSiteID = ParentProjectID
            };

            ValidateOwnership_Site(UserID, ParentProjectID);

            var project = GetSite(UserID, ParentProjectID);

            if (Location != null)
            {
                Location.CopyToSite(newSite);
            }
            else
            {
                project.Location.CopyToSite(newSite);
            }

            var newSiteID = _FolderingRepository.AddSite(UserID, newSite);

            return newSiteID;
        }

        public bool SaveSiteMapLocation(long UserID, long SiteID, MapLocationView Location)
        {
            var data = ValidateOwnership_Site(UserID, SiteID);
            Validate_RoleModify(data);

            var _locaion = new DAL.AdminLayer.Models.MapLocationData();
            Location.CopyToLocationDAL(_locaion);

            //update
            return _FolderingRepository.UpdateSiteLocation(SiteID, _locaion);
        }

        public async Task<bool> SaveDeviceMapLocationAsync(long UserID, string SN, MapPinLocationView Location, string AuthorizationHeaderValue)
        {
            var data = ValidateOwnership_SN(UserID, SN);
            Validate_RoleModify(data);

            var updateResult = _FolderingRepository.SaveDeviceLocation(SN, Location.Latitude.ToString(), Location.Longitude.ToString());

            if (updateResult)
            {
                try
                {
                    #region Call remote server to check this SN

                    try
                    {
                        Base.KnownDeviceType _knownType = this.CurrentSettings.SearchKnownDeviceType(SN);

                        var remoteAPI_URL = _knownType.BuildURL_UpdateDeviceLocation(SN, Location.Latitude.ToString(), Location.Longitude.ToString());

                        var client = new Connectors.HTTPLibrary.HttpClient.HttpClientHelper();

                        client.RequestHeaders = new System.Collections.Specialized.NameValueCollection();
                        client.RequestHeaders.Add("Authorization", $"{AuthorizationHeaderValue}");

                        var httpGetResult = await client.Get(remoteAPI_URL);
                        if (String.IsNullOrEmpty(httpGetResult))
                        {
                            //FAILED
                        }
                        else
                        {
                            var json = Newtonsoft.Json.Linq.JToken.Parse(httpGetResult);
                            bool updateRemoteResult = json["result"].ToString().ToLower() == "true";
                        }
                    }
                    catch
                    {
                    }

                    #endregion

                }
                catch
                {

                }
            }

            return updateResult;
        }

        public SiteMapContainerView GetSiteMapContainer(long UserID, long SiteID)
        {
            var nodeData = ValidateOwnership_Site(UserID, SiteID);
            var _site = GetSiteEntity(UserID, SiteID);

            var devices = _FolderingRepository.GetUserTreeDevices(SiteID, UserID);

            var siteMapInfo = new SiteMapContainerView(_site, devices)
            {
                SharedView = new TreeNodeView(nodeData)
            };
            return siteMapInfo;
        }

        public Device.DeviceListView[] GetSiteDevicesList(long UserID, long SiteID)
        {
            var mapContainer = GetSiteMapContainer(UserID, SiteID);

            return mapContainer.Devices;
        }

        public SessionSettingView[] GetSiteSessionSetting(long userID, long siteID)
        {
            ValidateOwnership_Site(userID, siteID);
            var list = _FolderingRepository.GetSiteSessionSetting(siteID).Select(u => new SessionSettingView(u)).ToList();
            //while(list.Count < 4)
            //{
            //    list.Add(new SessionSettingView() { SessionID = -1});
            //}

            return list.ToArray();
        }

        public bool UpdateSiteSessionSetting(long userID, long siteID, SessionSettingView[] sessionList)
        {
            var data = ValidateOwnership_Site(userID, siteID);
            Validate_RoleView(data);

            var result = false;
            SessionSettingView lastSession = null;

            var _sessionList = sessionList.OrderBy(s => s.StartDate).Where(s => s.StartDate != null && s.EndDate != null);

            foreach (var item in _sessionList)
            {
                if (item.IsDelete)
                {
                    result = _FolderingRepository.DeleteSessionSetting(item.SessionID);
                    continue;
                }

                if (lastSession != null && item.StartDate < lastSession.EndDate)
                {
                    item.StartDate = lastSession.EndDate.Value.AddDays(1);

                    if (item.EndDate < item.StartDate)
                    {
                        item.EndDate = item.StartDate.Value.AddDays(1);
                    }
                }

                result = _FolderingRepository.UpdateSessionSetting(new DAL.AdminLayer.Models.SessionSetting()
                {
                    EndDate = item.EndDate.Value,
                    EraID = item.EraID,
                    IsAutoUpdate = item.IsAutoUpdate,
                    IsIrrigationAllowed = item.IsIrrigationAllowed,
                    Name = item.Name,
                    RestrictionType = item.RestrictionType,
                    SessionID = item.SessionID,
                    SessionIndex = item.SessionIndex,
                    SiteID = siteID,
                    StartDate = item.StartDate.Value
                });

                lastSession = item;


            }
            return result;
        }

        public bool UpdateSiteSessionDay(long userID, long siteID, SessionDaySettingView[] sessionDaylist, long sessionID)
        {

            var result = false;
            if (sessionDaylist == null || sessionDaylist.Length == 0)
            {
                return result;
            }

            var data = ValidateOwnership_Site(userID, siteID);
            Validate_RoleView(data);

            foreach (var sessionDay in sessionDaylist)
            {
                var day = new DAL.AdminLayer.Models.SessionDaySetting()
                {
                    DayIndex = (byte)sessionDay.DayIndex,
                    MaxDailyCycles = sessionDay.MaxDailyCycles,
                    MaxDailyIrrigrationSeconds = sessionDay.MaxDailyIrrigrationSeconds,
                    Name = sessionDay.Name,
                    ParentSessionID = sessionDay.ParentSessionID,

                };
                result = _FolderingRepository.UpdateSiteSessionDay(sessionID, siteID, day, sessionDay.Times.Select(t => new DAL.AdminLayer.Models.TimeValueItem { Allow = t.Allow, Time = t.Time }).ToArray());
                if (!result)
                    return result;
            }

            return result;
        }

        public const int FIXED_TIMES = 7;
        public int[] START_TIMES = new int[] { 0, 14400, 28800, 43200, 57600, 72000, 86340 };

        public SessionDaySettingViewResponse GetSessionDaySetting(long userID, long siteID, long sessionID)
        {
            var data = ValidateOwnership_Site(userID, siteID);
            var SessionName = "";
            var list_db = _FolderingRepository.GetSessionDaySetting(sessionID, siteID, out SessionName);

            var _dayf = new List<SessionDaySettingView>();

            var _days = list_db
                    .OrderBy(g => g.DayIndex)
                    .ThenBy(g => g.Time)
                    .ToArray();

            var _times = list_db.GroupBy(t => t.Time)
                    .Select(t => t.Key)
                    .OrderBy(t => t)
                    .ToList();

            int missingTimes = FIXED_TIMES - _times.Count;

            var lastTime = missingTimes == FIXED_TIMES ? 0 : START_TIMES.FirstOrDefault(t => t > _times[0]);
            for (int i = 0; i < missingTimes; i++)
            {
                _times.Add(lastTime);
                lastTime = START_TIMES.FirstOrDefault(t => t > lastTime);
            }

            byte dindex = 0;
            byte tIndex = 0;

            SessionDaySettingView item = new SessionDaySettingView()
            {
                DayIndex = -1,
                Times = new List<TimeValueView>()
            };

            for (int i = 0; i < _days.Length; i++)
            {
                if (item.DayIndex != _days[i].DayIndex)
                {
                    #region fill times for previous item

                    while (tIndex < FIXED_TIMES && item.Times != null)
                    {
                        item.Times.Add(new TimeValueView()
                        {
                            Allow = true,
                            Time = _times[tIndex]
                        });
                        tIndex++;
                    }

                    #endregion

                    #region fill days between dindex and item

                    while (dindex < _days[i].DayIndex)
                    {
                        item = new SessionDaySettingView()
                        {
                            DayIndex = dindex,
                            Name = "",
                            ParentSessionID = sessionID,
                            MaxDailyIrrigrationSeconds = 0,
                            MaxDailyCycles = 0,
                            IsIrrigationAllowed = true,
                            Times = _times.Select(t => new TimeValueView() { Allow = true, Time = t }).ToList()
                        };
                        _dayf.Add(item);
                        dindex++;
                    }

                    #endregion

                    tIndex = 0;

                    item = new SessionDaySettingView()
                    {
                        DayIndex = _days[i].DayIndex,
                        Name = _days[i].Name,
                        ParentSessionID = _days[i].ParentSessionID,
                        MaxDailyIrrigrationSeconds = _days[i].MaxDailyIrrigrationSeconds,
                        MaxDailyCycles = _days[i].MaxDailyCycles,
                        IsIrrigationAllowed = true,
                        Times = new List<TimeValueView>()
                    };

                    dindex++;
                    _dayf.Add(item);
                }

                while (_times[tIndex] < _days[i].Time)
                {
                    item.Times.Add(new TimeValueView()
                    {
                        Allow = true,
                        Time = _times[tIndex]
                    });
                    tIndex++;
                }

                item.Times.Add(new TimeValueView()
                {
                    Allow = _days[i].IrrigationAllowed,
                    Time = _days[i].Time
                });

                tIndex++;
                item.IsIrrigationAllowed = item.IsIrrigationAllowed && _days[i].IrrigationAllowed;

            }

            #region fill last item's times

            while (tIndex < FIXED_TIMES)
            {
                item.Times.Add(new TimeValueView()
                {
                    Allow = true,
                    Time = _times[tIndex]
                });
                tIndex++;
            }

            item.Times = item.Times.OrderBy(t => t.Time).ToList();

            #endregion

            //fill rest of week
            while (dindex < 7)
            {
                item = new SessionDaySettingView()
                {
                    DayIndex = dindex,
                    Name = "",
                    ParentSessionID = sessionID,
                    MaxDailyIrrigrationSeconds = 0,
                    MaxDailyCycles = 0,
                    IsIrrigationAllowed = true,
                    Times = _times.Select(t => new TimeValueView() { Allow = true, Time = t }).ToList()
                };
                _dayf.Add(item);
                dindex++;
            }

            return new SessionDaySettingViewResponse()
            {
                ListDays = _dayf.OrderBy(d => d.DayIndex).ToArray(),
                SessionID = sessionID,
                SessionName = SessionName
            };
        }

        public MapPinLocationView GetDeviceLocaion(long UserID, string SN)
        {
            var device = ValidateOwnership_SN(UserID, SN);
            Validate_RoleView(device);

            if (device.AttachedDevice != null)
            {
                return new MapPinLocationView(device.AttachedDevice.Map_Latitude, device.AttachedDevice.Map_Longitude);
            }
            else
            {
                return new MapPinLocationView(device.DetachedDevice.Map_Latitude, device.DetachedDevice.Map_Longitude);
            }
        }

        public Device.DeviceInfoView GetDeviceInfo(long UserID, string SN)
        {
            var device = ValidateOwnership_SN(UserID, SN);
            Validate_RoleView(device);

            if (device.IsDetachedDevice)
            {
                var deviceInfo = new Device.DeviceInfoView()
                {
                    SN = device.DetachedDevice.SN,
                    DeviceID = device.DetachedDevice.DeviceID,
                    DeviceName = device.DetachedDevice.Name,
                    OtherDevicesView = null,
                    ParentSiteInfo = null
                };

                return deviceInfo;
            }
            else
            {
                var devices = _FolderingRepository.GetUserTreeDevices(device.AttachedDevice.SiteID, UserID);
                var siteInfo = _FolderingRepository.GetSiteInfo(UserID, device.AttachedDevice.SiteID);

                var deviceInfo = new Device.DeviceInfoView()
                {
                    SN = device.AttachedDevice.SN,
                    DeviceID = device.AttachedDevice.DeviceID,
                    DeviceName = device.AttachedDevice.DeviceName,
                    OtherDevicesView = devices
                                            .Select(d => new Device.DeviceListView(d))
                                            .ToArray(),
                    ParentSiteInfo = new Site.SiteInfoView(siteInfo)
                };

                return deviceInfo;
            }
        }

        public SiteInfoView GetSiteInfoView(long UserID, long SiteID)
        {
            var siteInfo = this.GetSiteInfo(UserID, SiteID);

            return new SiteInfoView(siteInfo);
        }

        public bool UpdateSite(long UserID, long SiteID, string SiteName)
        {
            var data = ValidateOwnership_Site(UserID, SiteID);
            Validate_RoleModify(data);
            return _FolderingRepository.UpdateSite(SiteID, SiteName);
        }

        public bool DeleteSite(long UserID, long SiteID)
        {
            var data = ValidateOwnership_Site(UserID, SiteID);
            Validate_RoleModify(data);

            return _FolderingRepository.DeleteSite(SiteID, UserID);
        }

        #endregion

        #region Site Sharing Steps

        public ViewModelLayer.Models.Site.SharedSiteSettingsView[] SiteSharedUsers_GetAllUsers(long UserID, long SiteID)
        {
            var data = ValidateOwnership_Site(UserID, SiteID);
            Validate_RoleModify(data);
            Validate_RoleAdmin(data);

            return _FolderingRepository.SharedUsers_GetAll(SiteID)
                                            .Where(u => u.LinkedUserID != UserID)
                                            .Select(u => new Site.SharedSiteSettingsView(u))
                                            .ToArray();
        }

        /*
        Pending. For the moment - keep it
        public bool SiteSharedUsers_DeleteUser(long UserID, long SiteID, long UserID_Delete)
        {
            var data = ValidateOwnership_Site(UserID, SiteID);
            Validate_RoleAdmin(data);

            return _FolderingRepository.SharedUsers_Delete(SiteID, UserID, UserID_Delete);
        }*/

        public ViewModelLayer.Models.Site.SharedSiteSettingsView[] SiteSharedUsers_Update(long CurrentUserID, string CurrentUserEmail, long SiteID, ViewModelLayer.Models.Site.SharedSiteSettingsView[] UsersList)
        {
            bool result = false;
            var data = ValidateOwnership_Site(CurrentUserID, SiteID);
            Validate_RoleAdmin(data);

            if (UsersList == null || UsersList.Length == 0)
            {
                return new ViewModelLayer.Models.Site.SharedSiteSettingsView[0];
            }

            //get current user
            var currentUser = BuildUserInfo(CurrentUserID);

            //get all users in site
            var alreadySharedUsers = _FolderingRepository.SharedUsers_GetAll(SiteID)
                               .ToArray();
            var finalUsersList = new List<ViewModelLayer.Models.Site.SharedSiteSettingsView>();

            DAL.AdminLayer.Models.User2Site existsUser = null;
            int existsUserIndex = -1;

            #region iterate over users in response

            SharedSiteSettingsView item = null;
            for (int userListIndex = 0; userListIndex < UsersList.Length; userListIndex++)
            {
                item = UsersList[userListIndex];

                //ignore any changes to current user or duplicated email in request
                if (item.Email == CurrentUserEmail)
                    continue;

                if (finalUsersList.Any(s => s.Email == item.Email))
                {
                    //prevent duplicates
                    item.VerificationStatus = SharingVerificationStatus.Failed2Share;
                }
                else
                {
                    existsUserIndex = -1;
                    existsUser = null;
                    for (int userIndex = 0; userIndex < alreadySharedUsers.Length; userIndex++)
                    {
                        if (alreadySharedUsers[userIndex].Email == item.Email)
                        {
                            existsUserIndex = userIndex;
                            existsUser = alreadySharedUsers[userIndex];
                        }
                    }
                    //existsUser = alreadySharedUsers.FirstOrDefault(u => u.Email == item.Email);
                    if (existsUser == null)
                    {
                        #region new user

                        if (!string.IsNullOrEmpty(item.Email))
                        {
                            //get target user
                            var targetUser = BuildUserInfo(item.Email);
                            if (targetUser == null)
                            {
                                //no such user
                                item.VerificationStatus = SharingVerificationStatus.NoSuchUser;
                            }
                            else
                            {
                                var u = new DAL.AdminLayer.Models.User2Site()
                                {
                                    RoleViewOnly = item.RoleViewOnly,
                                    SiteID = SiteID,
                                    RoleModify = item.RoleModify,
                                    RoleControlRT = item.RoleControlRT,
                                    RoleAdmin = item.RoleAdmin,
                                    LinkedUserID = targetUser.UserID,
                                    Email = targetUser.Email
                                };

                                bool? proccessComplete = null;
                                result = _FolderingRepository.SharedUsers_Add(CurrentUserID, u, out proccessComplete);

                                #region build and add message

                                if (result && u.LinkedUserID != -1)
                                {
                                    item.VerificationStatus = proccessComplete.GetValueOrDefault(false) ? SharingVerificationStatus.Accepted : SharingVerificationStatus.Pending;

                                    //folding data
                                    var folderingInfo = new User.Messages.BodyView.FolderingBodyView()
                                    {
                                        FolderingType = User.Messages.BodyView.FolderingBodyView.FolderingTypes.SiteShared,
                                        Location = new MapLocationView(_FolderingRepository.GetSiteLocation(SiteID)),
                                        SharingLevels = new User.Messages.FolderingMessageRolesView(u)
                                    };

                                    //create message and add to repository
                                    var messageView = new User.Messages.InboxMessageRecordView(targetUser, currentUser, folderingInfo);

                                    using (var userManager = new User.UserViewModelManager(this.CurrentSettings))
                                    {
                                        userManager.AddMessage(messageView);
                                    }

                                }
                                else
                                {
                                    item.VerificationStatus = SharingVerificationStatus.Failed2Share;
                                }

                                #endregion
                            }
                        }
                        else
                        {
                            item.VerificationStatus = SharingVerificationStatus.NoSuchUser;
                        }
                        #endregion
                    }
                    else
                    {
                        #region exists user

                        result = _FolderingRepository.SharedUsers_Update(CurrentUserID, new DAL.AdminLayer.Models.User2Site()
                        {
                            RoleViewOnly = item.RoleViewOnly,
                            SiteID = SiteID,
                            RoleModify = item.RoleModify,
                            RoleControlRT = item.RoleControlRT,
                            RoleAdmin = item.RoleAdmin,
                            Email = item.Email,
                            LinkedUserID = existsUser.LinkedUserID
                        });

                        if (result)
                        {
                            if (existsUser.IsVerified.HasValue)
                            {
                                item.VerificationStatus = existsUser.IsVerified.Value ? SharingVerificationStatus.Accepted : SharingVerificationStatus.Rejected;
                            }
                            else
                            {
                                item.VerificationStatus = SharingVerificationStatus.Pending;
                            }
                        }
                        else
                        {
                            item.VerificationStatus = SharingVerificationStatus.Failed2UpdateShare;
                        }


                        alreadySharedUsers[existsUserIndex] = null;

                        #endregion
                    }

                    finalUsersList.Add(item);
                }
            }

            #region delete old user from db

            //remote all remaining users in list
            foreach (var u in alreadySharedUsers)
            {
                if (u == null)
                    continue;

                result = _FolderingRepository.SharedUsers_Delete(SiteID, CurrentUserID, u.LinkedUserID);
            }

            #endregion

            #endregion

            return finalUsersList.ToArray();
        }

        #endregion

        #region Site Transfer Steps

        public long TransferSite_LocalTransfer(long UserID, long SiteID, long ProjectID)
        {
            var data = ValidateOwnership_Site(UserID, SiteID);
            Validate_RoleAdmin(data);
            data = ValidateOwnership_Site(UserID, ProjectID);
            return _FolderingRepository.LocalTransfer(ProjectID, SiteID, UserID) ? ProjectID : -1;
        }

        public TransferSiteStartResponseView TransferSite_Start(long SiteID, long CurrentUserID, string TargetUserEmail)
        {
            var data = ValidateOwnership_Site(CurrentUserID, SiteID);
            Validate_RoleAdmin(data);
            //data.SiteID = SiteID;

            //get and validate target user
            var targetUser = BuildUserInfo(TargetUserEmail);

            if (targetUser == null)
            {
                throw new Exceptions.SecurityException("User doesn't exist", Exceptions.SecurityException.EXCEPTION_TRANSFER);
            }

            if (targetUser.UserID == CurrentUserID)
            {
                throw new Exceptions.SecurityException("Transfer is not valid", Exceptions.SecurityException.EXCEPTION_TRANSFER);
            }

            var currentPendingTransfers = _FolderingRepository.SiteTransfer_GetAllPendings(SiteID, CurrentUserID);

            #region check for already open request for these users

            var openRequest = currentPendingTransfers.FirstOrDefault(r => r.TargetUserEmail == targetUser.Email);
            //check for this user if already got transfer request
            if (openRequest != null)
            {
                //already exists open transfer for this user
                if (!openRequest.RejectDate.HasValue)
                {
                    //return already open request details
                    return new TransferSiteStartResponseView()
                    {
                        SiteID = SiteID,
                        TargetUserEmail = TargetUserEmail,
                        TransferDate = openRequest.TransferDate,
                        IsCompleted = false,
                        Result = true
                    };
                }
            }

            #endregion

            #region build messages

            var folderingInfo = new User.Messages.BodyView.FolderingBodyView()
            {
                SourceSiteID = SiteID,
                FolderingType = User.Messages.BodyView.FolderingBodyView.FolderingTypes.SiteTransfer,
                Location = new MapLocationView(_FolderingRepository.GetSiteLocation(SiteID)),
                SharingLevels = new User.Messages.FolderingMessageRolesView(data)
            };

            //create message and add to repository
            var currentUser = BuildUserInfo(CurrentUserID);
            var messageView = new User.Messages.InboxMessageRecordView(targetUser, currentUser, folderingInfo);

            #endregion

            var newTranferRequest = new DAL.AdminLayer.Models.NewTransferSiteRequest()
            {
                SiteID = SiteID,
                SourceUserID = CurrentUserID,
                TargetUserID = targetUser.UserID,
                MessageID = messageView.MessageID
            };

            var result = _FolderingRepository.SiteTransfer_Start(newTranferRequest);
            if (result)
            {
                //commit the messages to target user in-box
                using (var userManager = new User.UserViewModelManager(this.CurrentSettings))
                {
                    userManager.AddMessage(messageView);
                }

                return new TransferSiteStartResponseView()
                {
                    SiteID = SiteID,
                    TargetUserEmail = TargetUserEmail,
                    TransferDate = DateTime.UtcNow,
                    IsCompleted = false,
                    Result = true
                };
            }
            else
            {
                throw new Exceptions.SecurityException("Failed to transfer site", Exceptions.SecurityException.EXCEPTION_TRANSFER);
            }
        }

        public bool TransferSite_Cancel(long UserID, long SiteID)
        {
            var data = ValidateOwnership_Site(UserID, SiteID);
            Validate_RoleAdmin(data);

            var pendingTransfers = _FolderingRepository.SiteTransfer_GetAllPendings(SiteID, UserID);

            bool result = true;
            foreach (var pendingRequest in pendingTransfers)
            {
                if (pendingRequest != null)
                {
                    //delete the pending message
                    using (var userManager = new User.UserViewModelManager(this.CurrentSettings))
                    {
                        result = result && userManager.DeleteMessage(pendingRequest.TargetUserEmail, pendingRequest.MessageID);
                    }

                    result = result && _FolderingRepository.SiteTransfer_Cancel(pendingRequest.SourceUserID, pendingRequest.SiteID);
                }
            }

            return result;
        }

        public bool TransferSite_Reject(string TargetUserEmail, string messageID)
        {
            var sharingData = _GetShareData(TargetUserEmail, messageID);

            //we must have the siteID to process the Reject.
            if (sharingData != null)
            {
                var pendingTransfers = _FolderingRepository.SiteTransfer_GetAllPendings(sharingData.SourceSiteID, null);
                var openRequest = pendingTransfers.FirstOrDefault(m => m.SiteID == sharingData.SourceSiteID
                                                                    && m.TargetUserEmail == TargetUserEmail
                                                                    && !m.RejectDate.HasValue
                                                                    && m.MessageID == messageID);

                if (openRequest != null)
                {
                    using (var userManager = new User.UserViewModelManager(this.CurrentSettings))
                    {
                        userManager.DeleteMessage(openRequest.TargetUserEmail, openRequest.MessageID);
                    }

                    return _FolderingRepository.SiteTransfer_Reject(openRequest.SourceUserID, openRequest.TargetUserID, sharingData.SourceSiteID);
                }
            }

            throw new Exceptions.SecurityException("No Pending message was found for this user", Exceptions.SecurityException.EXCEPTION_TRANSFER);
        }

        public ViewModelLayer.Models.Site.TransferSiteView TransferSite_GetAllPendings(long UserID, long SiteID)
        {
            var data = ValidateOwnership_Site(UserID, SiteID);
            Validate_RoleAdmin(data);

            var pendingRquests = _FolderingRepository.SiteTransfer_GetAllPendings(SiteID, UserID);

            return new ViewModelLayer.Models.Site.TransferSiteView(pendingRquests.FirstOrDefault());
        }

        public bool FolderinHydra2te_Accept(string UserEmail, string messageID, bool Accepted,
            long? TargetFolderingProjectID, string TargetFolderingNewProjectName)
        {
            var targetUser = BuildUserInfo(UserEmail);

            if (targetUser == null)
            {
                throw new Exceptions.SecurityException("User doesn't exist", Exceptions.SecurityException.EXCEPTION_TRANSFER);
            }

            var originalFolderingBodyView = _GetShareData(UserEmail, messageID);
            bool finalResult = false;

            if (originalFolderingBodyView != null)
            {
                switch (originalFolderingBodyView.FolderingType)
                {
                    case User.Messages.BodyView.FolderingBodyView.FolderingTypes.ProjectTransfer:
                    case User.Messages.BodyView.FolderingBodyView.FolderingTypes.SiteTransfer:

                        #region Transfer response
                        //get current pending transfers
                        var pendingTransfers = _FolderingRepository.SiteTransfer_GetAllPendings(originalFolderingBodyView.SourceSiteID, null);
                        var openTransferRequest = pendingTransfers.FirstOrDefault(m => m.SiteID == originalFolderingBodyView.SourceSiteID
                                                                        && m.TargetUserID == targetUser.UserID
                                                                        && m.MessageID == messageID
                                                                        && !m.RejectDate.HasValue);
                        //if transfer request still valid process it
                        if (openTransferRequest != null)
                        {
                            if (Accepted)
                            {
                                //create new project when given new name
                                if (!TargetFolderingProjectID.HasValue && !String.IsNullOrEmpty(TargetFolderingNewProjectName))
                                {
                                    using (var projectManager = new Project.ProjectViewModelManager(this.CurrentSettings))
                                    {
                                        TargetFolderingProjectID = projectManager.CreateProject(targetUser.UserID, TargetFolderingNewProjectName, null);
                                    }
                                }

                                finalResult = _FolderingRepository.SiteTransfer_Accept(originalFolderingBodyView.SourceSiteID, openTransferRequest.SourceUserID, TargetFolderingProjectID, targetUser.UserID);
                            }
                            else
                            {
                                //target user has rejected this transfer...
                                finalResult = _FolderingRepository.SiteTransfer_Reject(openTransferRequest.SourceUserID, targetUser.UserID, originalFolderingBodyView.SourceSiteID);
                            }
                        }

                        #endregion

                        break;
                    case User.Messages.BodyView.FolderingBodyView.FolderingTypes.SiteShared:
                    case User.Messages.BodyView.FolderingBodyView.FolderingTypes.ProjectShared:
                        #region Sharing response

                        var alreadySharedUsers = _FolderingRepository.SharedUsers_GetAll(originalFolderingBodyView.SourceSiteID)
                                                        .ToArray();

                        var openShareRequest = alreadySharedUsers.FirstOrDefault(u => u.Email == UserEmail);

                        //if share request still valid process it
                        if (openShareRequest != null)
                        {
                            if (Accepted)
                            {
                                //create new project when given new name
                                if (!TargetFolderingProjectID.HasValue && !String.IsNullOrEmpty(TargetFolderingNewProjectName))
                                {
                                    using (var projectManager = new Project.ProjectViewModelManager(this.CurrentSettings))
                                    {
                                        TargetFolderingProjectID = projectManager.CreateProject(targetUser.UserID, TargetFolderingNewProjectName, null);
                                    }
                                }

                                finalResult = _FolderingRepository.ShareSite_Accept(originalFolderingBodyView.SourceSiteID, targetUser.UserID, TargetFolderingProjectID);
                            }
                            else
                            {
                                //target user has rejected this transfer...
                                finalResult = _FolderingRepository.SharedUsers_Reject(originalFolderingBodyView.SourceSiteID, targetUser.UserID, targetUser.UserID);
                            }
                        }

                        #endregion
                        break;
                    default:
                        throw new Exceptions.SecurityException("Unknown message response was found.", Exceptions.SecurityException.EXCEPTION_TRANSFER);

                }
            }

            throw new Exceptions.SecurityException("No Pending message was found for this user", Exceptions.SecurityException.EXCEPTION_TRANSFER);
        }

        #endregion
    }
}
