using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Project
{
    public class ProjectListView
    {
        public string Name { get; set; }
        public long ProjectID { get; set; }
        
        public ProjectListView(DAL.AdminLayer.Models.ProjectTitle poject)
        {
            Name = poject.Name;
            ProjectID = poject.SiteID;
        }
    }
}
