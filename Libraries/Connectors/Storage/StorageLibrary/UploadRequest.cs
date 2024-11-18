using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.StorageLibrary
{
    public class UploadRequest
    {
        public ACLControl ACL { get; set; } = ACLControl.PublicRead;
        public string TargetPath { get; set; }
        public string ContentType { get; set; }
    }
}
