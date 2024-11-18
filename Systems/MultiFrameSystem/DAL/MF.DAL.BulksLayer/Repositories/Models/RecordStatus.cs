using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.BulksLayer.Repositories.Models
{
    public class RecordStatus
    {
        public string Id { set; get; }
        public string Index { set; get; }
        public string Operation { set; get; }
        public int Status { set; get; }
        public string Type { set; get; }
        public long Version { set; get; }
        public bool IsValid { set; get; }
        public bool Success { get; private set; }


        public RecordStatus()
        {

        }

        public RecordStatus(Connectors.ElasticsearchLibrary.Models.HitRecord status)
        {
            this.Id = status.Id;
            this.Index = status.Index;
            this.IsValid = status.IsValid;
            this.Operation = status.Operation;
            this.Status = status.Status;
            this.Type = status.Type;
            this.Version = status.Version;

            Success = this.IsValid && Status >= 200 && Status < 300;
        }
    }
}
