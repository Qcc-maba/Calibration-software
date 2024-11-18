using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.BulksLayer.Repositories.Common.Models
{
    public abstract class SearchRecordsResponse<T> where T : class
    {
        public IEnumerable<T> Records { get; set; }
    }
}
