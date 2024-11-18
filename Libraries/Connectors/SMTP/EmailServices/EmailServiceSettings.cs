using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;
using System.Xml.Serialization;

namespace Maba.Connectors.EmailServices
{
    public class EmailServiceSettings
    {
        public const string DEFAULT_XSLT_FOLDER = "XSLTemplates";
        #region properties

        [XmlAttribute]
        public virtual string ConnectorType { get; set; }

        [XmlAttribute]
        public bool InEnabled { get; set; }

        [XmlElement(IsNullable = true)]
        public string DefaultFromAddress { get; set; }

        [XmlElement(IsNullable = true)]
        public string DefaultDisplayName { get; set; }

        public bool ForceSenderAddress { get; set; }

        [XmlElement(IsNullable = true)]
        public string Host { get; set; }
        public int Port { get; set; }
        public bool UseDefaultCredentials { get; set; }
        public bool EnableSsl { get; set; }

        [XmlElement(IsNullable = true)]
        public string Credential_UserName { get; set; }

        [XmlElement(IsNullable = true)]
        public string Credential_Password { get; set; }
        public int Timeout { get; set; }

        public string FolderXSLTFlies { get; set; }

        #endregion

        #region ctor

        public EmailServiceSettings()
        {
            ForceSenderAddress = true;
            ConnectorType = "Default";
            Port = 25;
            Host = "localhost";
            UseDefaultCredentials = true;
            EnableSsl = false;
            Timeout = 5000;
        }

        #endregion

        public string GetXSLTFile(string filename, string rootPath = null)
        {
            var folder = GetFolderXSLT(rootPath);
            return Path.Combine(folder, filename);
        }
        public string GetFolderXSLT(string rootPath = null)
        {
            if (String.IsNullOrEmpty(FolderXSLTFlies))
            {
                return String.IsNullOrEmpty(rootPath) ? DEFAULT_XSLT_FOLDER : Path.Combine(rootPath, DEFAULT_XSLT_FOLDER);
            }
            else
            {
                if (Path.IsPathRooted(FolderXSLTFlies))
                {
                    return FolderXSLTFlies;
                }
                else
                {
                    return Path.Combine(rootPath, FolderXSLTFlies);
                }
            }
        }

        #region static methods

        public static IEmailSenderConnector Create(EmailServiceSettings settings)
        {
            switch (settings.ConnectorType)
            {
                //case Connectors.SMTPServerConnector.CONNECTOR_TYPE:
                //    return new Connectors.SMTPServerConnector(settings);
            }

            return null;
        }

        #endregion
    }
}
