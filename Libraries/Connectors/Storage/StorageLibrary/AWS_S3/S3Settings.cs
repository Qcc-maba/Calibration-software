using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.StorageLibrary.AWS_S3
{
    public class S3Settings
    {
        public string DefaultBucketName { get; set; }
        public string DefaultFolder { get; set; }

        public string AwsAccessKeyId { get; set; }
        public string AwsSecretAccessKey { get; set; }
        public string Region { get; set; }

        public S3Settings()
        {
        }
    }
}
