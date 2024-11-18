using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.JsonHelpersLibrary.HierarchyFiles
{
    public class ReaderAttribute : Attribute
    {
        public string Name { get; set; }
        public bool Exclude { get; set; }

        public ReaderAttribute()
            : base()
        {
            Exclude = false;
        }
    }
}
