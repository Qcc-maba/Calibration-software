using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.User.Messages.BodyView
{
    public class FolderingBodyView : IMessageBodyView
    {
        #region CONSTANTS

        public const string MESSAGE_TYPE = "Foldering";

        #endregion

        #region enums

        public enum FolderingTypes
        {
            ProjectTransfer = 1,
            ProjectShared = 2,
            SiteTransfer = 3,
            SiteShared = 4
        }

        public enum MessagesStatus
        {
            Active = 1,
            Accepted = 2,
            Rejected = 3
        }

        #endregion

        #region properties

        [JsonConverter(typeof(StringEnumConverter))]
        public FolderingTypes FolderingType { get; set; }

        public MapLocationView Location { set; get; }

        public FolderingMessageRolesView SharingLevels { set; get; }

        public long SourceSiteID { set; get; }


        #endregion

        #region IMessageBody members

        public string MessageType
        {
            get
            {
                return MESSAGE_TYPE;
            }
            set { }
        }

        #endregion
    }
}
