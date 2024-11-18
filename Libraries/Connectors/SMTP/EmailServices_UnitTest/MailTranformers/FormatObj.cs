using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Xml.Serialization;

namespace Maba.Connectors.EmailServices.Tests.MailTranformers
{
    public class FormatObj
    {
        [XmlElement]
        public ProjectClass Project { get; set; }

        [XmlArray]
        public ProjectClass[] Projects { get; set; }

        public string Name { get; set; }
        public int[] MyValue { get; set; }

        public FormatObj()
        {

        }

        public string Function1(string parameter1, int parameter2, string parameter3)
        {
            return String.Format("{0}/{1}/{2}", parameter1, parameter2, parameter3);
        }
    }

    public class ProjectClass
    {
        [XmlElement]
        public string Name { get; set; }

        [XmlAttribute]
        public int ID { get; set; }
    }
}
