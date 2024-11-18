using Newtonsoft.Json.Linq;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.JsonHelpersLibrary
{
    public class JSONPrinter
    {
        private readonly List<int> _hashListOfFoundElements = new List<int>();
        private object Element = null;

        private JToken _Print(object obj)
        {           
            if (obj == null)
            {
                return null;
            }
            else if (obj is ValueType || obj is string)
            {
                return obj.ToString();
            }
            else
            {
                if (obj != null)
                {
                    if (_hashListOfFoundElements.Contains(obj.GetHashCode()))
                    {
                        return String.Format("[{0}]<!Recursive!>", obj.GetType().Name);
                    }
                    else
                    {
                        _hashListOfFoundElements.Add(obj.GetHashCode());
                    }
                }
                var _type = obj.GetType();
                var json = new JObject();

                if (typeof(IEnumerable).IsAssignableFrom(_type))
                {
                    var enumerableElement = obj as IEnumerable;
                    if (enumerableElement != null)
                    {
                        var arr = new JArray();
                        foreach (var e in enumerableElement)
                        {
                            arr.Add(_Print(e));
                        }

                        return arr;
                    }
                }
                else
                {

                    foreach (var p in _type.GetProperties())
                    {
                        json.Add(new JProperty(p.Name, _Print(p.GetValue(obj))));
                    }
                }
                return json;
            }
        }

        public JSONPrinter(object o)
        {
            Element = o;
        }

        public static object Print(object obj)
        {
            var p = new JSONPrinter(obj);
            return p._Print(obj);
        }
    }
}
