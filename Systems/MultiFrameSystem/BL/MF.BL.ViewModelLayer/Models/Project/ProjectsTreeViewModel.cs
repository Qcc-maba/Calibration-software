using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Project
{
    public class ProjectsTreeViewModel
    {
        public ProjectTreeContainerView[] Projects { get; set; }

        public string SearchText { get; set; }
        public long TotalProjects { get; set; }
        public long CurrentPageNumber { get; set; }
        public long CurrentPageSize { get; set; }
    }
}
