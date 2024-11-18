using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.BulksLayer.Repositories.Models
{
    public class BaseSearchMetadataView
    {
        public DateTime? StartDate { get; set; }
        public DateTime? EndDate { get; set; }

        public long TotalItems { get; set; }
        public int CurrentPage { get; set; }
        public int PageSize { get; set; }
    }
}
