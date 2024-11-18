using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.EmailServices.MailTemplateTranformers
{
    public class ParameterValue
    {
        public string Name { get; set; }
        public string NamespaceUri { get; set; }

        public object Value { get; set; }

        public ParameterValue(string ns, object val)
        {
            Name = null;
            NamespaceUri = ns;
            Value = val;
        }
        public ParameterValue(string name, string ns, object val)
        {
            this.Name = name;
            NamespaceUri = ns;
            this.Value = val;
        }
    }
}
