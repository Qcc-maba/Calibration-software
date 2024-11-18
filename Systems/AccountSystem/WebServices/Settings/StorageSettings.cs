using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.Connectors.JsonHelpersLibrary.HierarchyFiles;

namespace Maba.AccountSystem.WebServices.Settings
{
    public class StorageSettings : Connectors.JsonHelpersLibrary.HierarchyFiles.ISettingsCorrect
    {
        public string Profiles_PublicAccessUrl { get; set; }
        public string Profiles_PublicDefaultImageUrl { get; set; }

        public Connectors.StorageLibrary.AWS_S3.S3Settings Profiles_S3Settings { get; set; }


        public StorageSettings()
        {
        }

        public Connectors.StorageLibrary.IStorageConnector GetStorageService()
        {
            if (Profiles_S3Settings == null)
                return null;

            return new Connectors.StorageLibrary.AWS_S3.BaseS3Connector(this.Profiles_S3Settings);
        }

        public string CorrectImageUri(string userImage)
        {
            if (String.IsNullOrEmpty(userImage))
            {
                return this.Profiles_PublicDefaultImageUrl;
            }
            else
            {
                return $"{this.Profiles_PublicAccessUrl}/{userImage}";
            }
        }


        #region ISettingsCorrect

        void ISettingsCorrect.CorrectValues()
        {
            while (!String.IsNullOrEmpty(this.Profiles_PublicAccessUrl) && this.Profiles_PublicAccessUrl.EndsWith("/"))
            {
                this.Profiles_PublicAccessUrl = this.Profiles_PublicAccessUrl.Substring(0, this.Profiles_PublicAccessUrl.Length - 1);
            }
        }

        #endregion
    }
}
