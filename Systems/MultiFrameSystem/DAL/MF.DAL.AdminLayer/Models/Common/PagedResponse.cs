using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models.Common
{
    public class PagedResponse<T>
    {
        public long TotalItems { get; set; }
        public T[] CurrentPageItems { get; set; }
        public int CurrentPageNumber { get; set; }
        public int CurrentPageSize { get; set; }
    }
}
