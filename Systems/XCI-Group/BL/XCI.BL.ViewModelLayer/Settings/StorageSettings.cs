using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Settings
{
    public class StorageSettings
    {
        public string Zones_CustomerImagesUrl { get; set; }
        public string Zones_PublicDefaultImageTemplateUrl { get; set; }

        public string ZonesCaregories_PublicImagesUrl { get; set; }

        public int Zones_PublicDefaultImages { get; set; } = 24;

        public Connectors.StorageLibrary.AWS_S3.S3Settings Zones_CustomerUploads_S3Settings { get; set; }


        #region ctor

        public StorageSettings()
        {

        }

        #endregion

        #region public methods

        public Connectors.StorageLibrary.IStorageConnector GetStorageService()
        {
            if (Zones_CustomerUploads_S3Settings == null)
                return null;

            return new Connectors.StorageLibrary.AWS_S3.BaseS3Connector(this.Zones_CustomerUploads_S3Settings);
        }

        public string GetZoneDefaultImage(string ZoneImageUrl, int ZoneNumber)
        {
            if (!string.IsNullOrEmpty(ZoneImageUrl))
            {
                return String.Format(Zones_CustomerImagesUrl, ZoneImageUrl);
            }

            if (String.IsNullOrEmpty(Zones_PublicDefaultImageTemplateUrl))
            {
                return null;
            }

            return String.Format(Zones_PublicDefaultImageTemplateUrl, 1 + (ZoneNumber % this.Zones_PublicDefaultImages));
        }

        public string GetAdvisorImage(string imageUrl)
        {
            return ZonesCaregories_PublicImagesUrl == null ? imageUrl : $"{ZonesCaregories_PublicImagesUrl}/{imageUrl}";
        }
        #endregion
    }
}
