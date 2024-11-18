using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models
{
    public class TreePagedResponse
    {
        public long TotalProjects { get; set; }
        /// <summary>
        /// May be different that CurrentPageItems.Lenght.
        /// Since CurrentPageItems contains entire tree.
        /// </summary>
        public TreeNode[] CurrentPageItems { get; set; }
        public int CurrentPageNumber { get; set; }
        public int CurrentPageSize { get; set; }

    }
}
