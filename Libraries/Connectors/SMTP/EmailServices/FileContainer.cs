using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Xml;

namespace Maba.Connectors.EmailServices
{
    public class FileContainer
    {
        public DateTime LastDate { set; get; }
        public XmlReader XmlReader { set; get; }
        public string fileName { set; get; }
    }
}
