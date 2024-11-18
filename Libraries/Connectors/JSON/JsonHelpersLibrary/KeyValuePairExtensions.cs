using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.JsonHelpersLibrary
{
    public static class KeyValuePairExtensions
    {
        public static void Add<K, T>(this List<KeyValuePair<K, T>> keys, K key, T value)
        {
            keys.Add(new KeyValuePair<K, T>(key, value));
        }

        public static string Get(this List<KeyValuePair<string, string>> keys, string key, string defaultValue = null)
        {
            return Get<string, string>(keys, key, defaultValue);
        }
        public static T Get<K, T>(this List<KeyValuePair<K, T>> keys, K key, T defaultValue = default(T))
        {
            foreach (var k in keys)
            {
                if (k.Key.Equals(key))
                {
                    return k.Value;
                }
            }

            return defaultValue;
        }
    }
}
