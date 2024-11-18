using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Project
{
    public enum LoginExchangeView
    {
        Welcome,
        Device,
        Site,
        Project
    }
    public class ExchangeView
    {
        internal long UserID { get; private set; }

        public long? Entry_SiteID { get; set; }

        public long? Entry_ProjectID { get; set; }
        public string Entry_SN { set; get; }

        [JsonConverter(typeof(StringEnumConverter))]
        public LoginExchangeView LoginExchangeView { set; get; }
        public int DeviceCount { set; get; }
        public int RootSiteCount { set; get; }
        public int SiteTotalCount { set; get; }

        public int UpdateVersion { set; get; }


        public ExchangeView()
        {

        }


        public ExchangeView(DAL.AdminLayer.Models.Exchange e)
        {
            UserID = e.UserID;

            Entry_SiteID = e.Entry_SiteID;
            Entry_ProjectID = e.Entry_ProjectID;
            Entry_SN = e.Entry_SN;
            DeviceCount = e.DeviceCount;
            RootSiteCount = e.RootSiteCount;
            SiteTotalCount = e.SiteTotalCount;
            UpdateVersion = e.UpdateVersion;

            LoginExchangeView = Project.LoginExchangeView.Welcome;


            //Project = 0                       WELCOME
            //-----------------------------------------

            //PROJECT = 1
            //  > DEVICE = 0
            //          >SITES = 0              PROJECT
            //          >SITES = 1              SITE
            //          >SITES > 1              PROJECT

            //  > DEVICE = 1                    DEVICE

            //  > DEVICE > 1
            //          >SITES = 0              PROJECT
            //          >SITES = 1              SITE
            //          >SITES > 1              PROJECT

            //-----------------------------------

            //PROJECT > 1                       PROJECT

            if (RootSiteCount == 0)
            {
                LoginExchangeView = Project.LoginExchangeView.Welcome;
            }
            if (RootSiteCount == 1)
            {
                if (DeviceCount == 0)
                {
                    if (SiteTotalCount == 0)
                    {
                        LoginExchangeView = Project.LoginExchangeView.Project;
                    }
                    else if (SiteTotalCount == 1)
                    {
                        LoginExchangeView = Project.LoginExchangeView.Site;
                    }
                    else
                    {
                        LoginExchangeView = Project.LoginExchangeView.Project;
                    }
                }
                else if (DeviceCount == 1)
                {
                    LoginExchangeView = Project.LoginExchangeView.Device;
                }
                else
                {
                    if (SiteTotalCount == 0)
                    {
                        LoginExchangeView = Project.LoginExchangeView.Project;
                    }
                    else if (SiteTotalCount == 1)
                    {
                        LoginExchangeView = Project.LoginExchangeView.Site;
                    }
                    else
                    {
                        LoginExchangeView = Project.LoginExchangeView.Project;
                    }
                }
            }
            else if (RootSiteCount > 1)
            {
                LoginExchangeView = Project.LoginExchangeView.Project;
            }
        }

        public long Get_UserID()
        {
            return this.UserID;
        }
    }
}
