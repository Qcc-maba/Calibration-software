using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.JsonHelpersLibrary.Test.TestClasses
{
    public class TypeB
    {
        public string Name { get; set; }
        public long ID_Long { get; set; }
        public int ID_Int { get; set; }
        public bool Enabled { get; set; }
        public string[] Keys { get; set; }
        public List<KeyValuePair<string, string>> PKeys { get; set; }
    }

}
