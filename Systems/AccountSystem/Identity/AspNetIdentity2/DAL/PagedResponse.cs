using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.DAL
{
    public class PagedResponse<T>
    {
        public int RequestedPageNumber { get; set; }
        public int RequestedPageSize { get; set; }
        public long TotalItems { get; set; }

        public T[] Items { get; set; }
    }
}
