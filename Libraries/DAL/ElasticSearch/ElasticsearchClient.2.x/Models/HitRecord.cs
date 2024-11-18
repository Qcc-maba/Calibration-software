using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.ElasticsearchLibrary.Models
{
    public class HitRecord
    {
        public string Id { set; get; }
        public string Index { set; get; }
        public string Operation { set; get; }
        public int Status { set; get; }
        public string Type { set; get; }
        public long Version { set; get; }
        public bool IsValid { set; get; }
    }
}
