using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.Project
{
    public class ProjectView
    {
        public string Name { get; set; }
        public long ProjectID { get; set; }
        public DateTime CreationDate { get; set; }
        public MapLocationView Location { get; set; }

        public ProjectView()
        {

        }

        public ProjectView(DAL.AdminLayer.Models.Project p)
        {
            this.Name = p.Name;
            this.ProjectID = p.SiteID;
            Location = new MapLocationView(p);
           
        }
    }
}
