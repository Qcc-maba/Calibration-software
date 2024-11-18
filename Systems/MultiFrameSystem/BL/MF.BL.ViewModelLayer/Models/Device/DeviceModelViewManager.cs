using Newtonsoft.Json.Linq;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Device
{
    public class DeviceModelViewManager : Base.BaseViewModelManager
    {
        #region CONSTANTS

        public const int DEVICE_STATUS__ACTIVE = 10;

        #endregion

        #region members

        private DAL.AdminLayer.Repositories.Device.IDeviceRepository _DeviceRepository = null;

        #endregion

        #region ctor

        public DeviceModelViewManager(Base.ViewModelSettings currentSettings)
            : base(currentSettings)
        {
            _DeviceRepository = currentSettings.DAL_AdminLayer_RepositoriesGenerator.Generator_IDeviceRepository();
        }

        #endregion

        #region BaseViewModelManager members

        protected override void OnDispose()
        {
            if (_DeviceRepository != null)
            {
                this._DeviceRepository.Dispose();
            }
        }

        #endregion

        #region Device ViewModel methods

        public bool AttachDeviceToSite(long UserID, string SN, long? SiteID,
                                        decimal? lat, decimal? lot)
        {
            var device = _DeviceRepository.GetDevice(SN);
            if (SiteID.HasValue)
            {
                var data = ValidateOwnership_Site(UserID, SiteID.Value);
                Validate_RoleModify(data);
            }
            else
            {
                //if device was attached before - test the previous site
                if (device.ParentSiteID.HasValue)
                {
                    var data = ValidateOwnership_Site(UserID, device.ParentSiteID.Value);
                    Validate_RoleModify(data);
                }
            }

            var lat_str = lat.HasValue ? lat.ToString() : string.Empty;
            var lot_str = lot.HasValue ? lot.ToString() : string.Empty;

            return _DeviceRepository.AttachDeviceToSite(device.DeviceID, SiteID, lat_str, lot_str);
        }

        public bool UpdateDevice_AlertsSettings(long UserID, string SN, bool AlertEnabled)
        {
            var data = ValidateOwnership_SN(UserID, SN);
            Validate_RoleModify(data);

            return _DeviceRepository.UpdateAlertsEnabled(SN, AlertEnabled);
        }

        public DeviceAlertSettingsView[] GetDeviceAlertSettings(long UserID, string SN)
        {
            var data = ValidateOwnership_SN(UserID, SN);
            return _DeviceRepository.GetDeviceAlertSettings(SN)
                                        .Select(u => new DeviceAlertSettingsView(u, SN))
                                        .ToArray();
        }

        public bool UpdateDeviceAlertSettings(long UserID, string SN, DeviceAlertSettingsView[] deviceAlertSettingsView)
        {
            var data = ValidateOwnership_SN(UserID, SN);
            Validate_RoleModify(data);
            bool result = false;
            foreach (var item in deviceAlertSettingsView)
            {
                result = _DeviceRepository.UpdateDeviceAlertSettings(SN, new DAL.AdminLayer.Models.DeviceAlertSettings()
                {
                    AlertCode = item.AlertCode,
                    IsEmailEnable = item.IsEmailEnable,
                    IsSMSEnable = item.IsSMSEnable,
                    IsEnable = item.IsEnable,
                });

                if (!result)
                    return result;
            }

            return result;
        }

        public DeviceView GetDevice(long UserID, string SN)
        {
            var data = ValidateOwnership_SN(UserID, SN);

            return new DeviceView(_DeviceRepository.GetDevice(SN));
        }

        public bool UnlinkDevice(long UserID, string SN, long? NewParentSiteID)
        {
            var deviceInfo = ValidateOwnership_SN(UserID, SN);
            Validate_RoleModify(deviceInfo);

            if (NewParentSiteID.HasValue)
            {
                ValidateOwnership_Site(UserID, NewParentSiteID.Value);
            }
            return _DeviceRepository.AttachDeviceToSite(deviceInfo.DeviceID, NewParentSiteID, null, null);
        }

        public DeviceTypeView GetDeviceType(long UserID, string SN)
        {
            var data = ValidateOwnership_SN(UserID, SN);
            return new DeviceTypeView(_DeviceRepository.GetDeviceType(SN));
        }

        public async Task<SearchDeviceTypeModel> FindDeviceTypeAsync(long NewOwnerUserID, string SN, string AuthorizationHeaderValue)
        {
            var response = new SearchDeviceTypeModel()
            {
                Status = false
            };

            //search for known type
            Base.KnownDeviceType _knownType = this.CurrentSettings.SearchKnownDeviceType(SN);

            if (_knownType == null)
                return response;

            var DAL_SystemTypes = _DeviceRepository.GetDeviceTypes(_knownType.DeviceTypeName);
            if (DAL_SystemTypes == null || DAL_SystemTypes.Length == 0)
                return response;

            response.SystemDeviceType = new DeviceTypeView(DAL_SystemTypes[0]);

            #region check local system for this SN

            var device = _DeviceRepository.GetDevice(SN);

            if (device != null)
            {
                response.MaxZones = device.MaxZones;

                //it's already in use.
                if (device.ParentSiteID.HasValue)
                {
                    var ownsershipCheck = ValidateOwnership_SN(NewOwnerUserID, SN, throwExceptions: false).IsValid;
                    response.Status = ownsershipCheck;

                    if (ownsershipCheck)
                    {
                        response.SelfOwned = true;
                        response.StatusReason = StatusReasons.AlreadyTakenByThisUser;
                        response.Device = new ExistsDeviceInfoModel()
                        {
                            Location = new MapPinLocationView(device.Map_Latitude, device.Map_Longitude),
                            Name = device.Name
                        };
                    }
                    else
                    {
                        response.SelfOwned = false;
                        response.StatusReason = StatusReasons.AlreadyTaken;
                    }
                }
                else
                {
                    //it's not connected. so it's available.
                    response.StatusReason = StatusReasons.Success;
                    response.Status = true;
                }
            }
            else
            {
                //it's OK. this device is available here.. 

                #region Call remote server to check this SN

                try
                {
                    //_knownType.
                    var remoteAPI_URL = _knownType.BuildURL_VerifySN(SN);

                    var client = new Connectors.HTTPLibrary.HttpClient.HttpClientHelper();

                    client.RequestHeaders = new System.Collections.Specialized.NameValueCollection();
                    client.RequestHeaders.Add("Authorization", $"{AuthorizationHeaderValue}");

                    var httpGetResult = await client.Get(remoteAPI_URL);
                    if (String.IsNullOrEmpty(httpGetResult))
                    {
                        response.StatusReason = StatusReasons.MissingDevice;
                        response.Status = false;
                        response.MaxZones = 0;
                    }
                    else
                    {
                        var json = JToken.Parse(httpGetResult);
                        response.Status = json["result"].ToString().ToLower() == "true";
                        if (response.Status)
                        {
                            response.MaxZones = int.Parse(json["body"]["maxZones"].ToString());
                        }
                        response.StatusReason = StatusReasons.Success;
                    }

                }
                catch
                {

                }

                #endregion

                response.StatusReason = StatusReasons.Success;
                response.Status = true;
                response.MaxZones = 16;
            }

            #endregion


            return response;
        }

        public async Task<AddDeviceResponseModel> AddDeviceAsync(string NewOwnerUserEmail, long NewOwnerUserID, AddDeviceRequestModel NewDeviceRequest, string AuthorizationHeaderValue)
        {
            var searchResult = await FindDeviceTypeAsync(NewOwnerUserID, NewDeviceRequest.SN, AuthorizationHeaderValue);

            if (searchResult == null || !searchResult.Status)
            {
                return new AddDeviceResponseModel()
                {
                    SN = NewDeviceRequest.SN,
                    Status = false
                };
            }

            //verify ownership of this site by user
            if (NewDeviceRequest.ParentSiteID.HasValue)
            {
                //check security user-ParentSiteID
                this.ValidateOwnership_Site(NewOwnerUserID, NewDeviceRequest.ParentSiteID.Value);
            }
            else
            {
                //get exchange. if Welcome - create dummy project
                using (var projectManager = new Project.ProjectViewModelManager(this.CurrentSettings))
                {
                    var exhangeResult = projectManager.GetUserExchange(NewOwnerUserEmail);
                    if (exhangeResult.LoginExchangeView == Project.LoginExchangeView.Welcome)
                    {
                        //create dummy project
                        var location = new MapLocationView()
                        {
                            MapCenter = NewDeviceRequest.Location,
                            AutoBounds = true,
                            ZoomLevel = 10
                        };
                        NewDeviceRequest.ParentSiteID = projectManager.CreateProject(NewOwnerUserID, "My First Project", location);
                    }
                    else
                    {
                        if (exhangeResult.RootSiteCount == 0)
                        {
                            throw new Exceptions.InternalOperationalErrorException("(A) Failed to create first project to user!");

                        }
                        else
                        {
                            NewDeviceRequest.ParentSiteID = exhangeResult.Entry_ProjectID ?? exhangeResult.Entry_SiteID;
                        }
                    }
                }

                //by now, we should have value on [NewDeviceRequest.ParentSiteID]
                if (!NewDeviceRequest.ParentSiteID.HasValue)
                {
                    throw new Exceptions.InternalOperationalErrorException("(B) Failed to create first project to user!");
                }
            }

            AddDeviceResponseModel response = null;
            if (searchResult.SelfOwned)
            {
                #region for self device owned - attach device to this new device

                var existsDevice = _DeviceRepository.GetDevice(NewDeviceRequest.SN);
                if (existsDevice == null)
                {
                    response = new AddDeviceResponseModel()
                    {
                        SN = NewDeviceRequest.SN,
                        Status = false,
                        SelfOwned = searchResult.SelfOwned,
                        StatusReason = searchResult.StatusReason,
                        SystemDeviceType = searchResult.SystemDeviceType,
                        ParentSiteID = NewDeviceRequest.ParentSiteID
                    };
                }
                else
                {
                    //reattach this device to [NewDeviceRequest.ParentSiteID]
                    var reAttachedResult = _DeviceRepository.AttachDeviceToSite(existsDevice.DeviceID,
                                                                                NewDeviceRequest.ParentSiteID,
                                                                                NewDeviceRequest.Location.Latitude.ToString(),
                                                                                NewDeviceRequest.Location.Longitude.ToString());

                    //refresh user entry point (exchange)
                    using (var accountManager = new User.UserViewModelManager(this.CurrentSettings))
                    {
                        accountManager.RefreshUserExhange(NewOwnerUserID);
                    }

                    response = new AddDeviceResponseModel()
                    {
                        SN = NewDeviceRequest.SN,
                        Status = reAttachedResult,
                        SelfOwned = searchResult.SelfOwned,
                        StatusReason = searchResult.StatusReason,
                        SystemDeviceType = searchResult.SystemDeviceType,
                        ParentSiteID = NewDeviceRequest.ParentSiteID
                    };
                }

                #endregion
            }
            else
            {
                var newDeviceID = _DeviceRepository.CreateDevice(
                                                                    NewDeviceRequest.SN,
                                                                    NewDeviceRequest.DeviceName,
                                                                    NewDeviceRequest.ParentSiteID,
                                                                    DEVICE_STATUS__ACTIVE,
                                                                    NewDeviceRequest.Location.Latitude.ToString(),
                                                                    NewDeviceRequest.Location.Longitude.ToString(),
                                                                    searchResult.SystemDeviceType.TypeID,
                                                                    NewDeviceRequest.ActiveZones);

                //refresh user entry point (exchange)
                using (var accountManager = new User.UserViewModelManager(this.CurrentSettings))
                {
                    accountManager.RefreshUserExhange(NewOwnerUserID);
                }

                response = new AddDeviceResponseModel()
                {
                    SN = NewDeviceRequest.SN,
                    Status = newDeviceID >= 0,
                    SelfOwned = searchResult.SelfOwned,
                    StatusReason = searchResult.StatusReason,
                    SystemDeviceType = searchResult.SystemDeviceType
                };
            }

            if (response.Status)
            {
                #region Call remote server to check this SN

                try
                {
                    Base.KnownDeviceType _knownType = this.CurrentSettings.SearchKnownDeviceType(NewDeviceRequest.SN);

                    var remoteAPI_URL = _knownType.BuildURL_ActivateSN(NewDeviceRequest.SN);

                    var client = new Connectors.HTTPLibrary.HttpClient.HttpClientHelper();

                    client.RequestHeaders = new System.Collections.Specialized.NameValueCollection();
                    client.RequestHeaders.Add("Authorization", $"{AuthorizationHeaderValue}");

                    var httpGetResult = await client.Get(remoteAPI_URL);
                    if (String.IsNullOrEmpty(httpGetResult))
                    {
                        response.StatusReason = StatusReasons.RemoteCreationFailed;
                        response.Status = false;
                        response.MaxZones = 0;
                    }
                    else
                    {
                        var json = JToken.Parse(httpGetResult);
                        response.Status = json["result"].ToString().ToLower() == "true";
                        if (response.Status)
                        {
                            response.MaxZones = int.Parse(json["body"]["maxZones"].ToString());
                        }
                        response.StatusReason = StatusReasons.Success;
                    }
                }
                catch
                {
                    response.Status = false;
                }

                #endregion

            }

            return response;
        }

        #endregion

        public bool UpdateDeviceName(long UserID, string SN, string Name)
        {
            Validate_RoleModify(ValidateOwnership_SN(UserID, SN));
            return _DeviceRepository.UpdateDeviceName(SN, Name);
        }
    }
}
