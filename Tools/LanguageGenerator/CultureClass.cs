using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace LanguageGenerator
{
    public class CultureClass
    {
        public string Key { set; get; }
        public string Name { set; get; }

        public override string ToString()
        {
            return  String.Format("({0,-2}) {1}" ,Key ,Name);
        }
    }
}
