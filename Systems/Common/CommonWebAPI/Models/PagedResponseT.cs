using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.Common.CommonWebAPI.Models
{
    public class PagedResponse<T> : Response<T[]>
    {
        public int RequestedPageNumber { get; set; }
        public int RequestedPageSize { get; set; }
        public long TotalItems { get; set; }

        public PagedResponse()
        {

        }
    }
}
