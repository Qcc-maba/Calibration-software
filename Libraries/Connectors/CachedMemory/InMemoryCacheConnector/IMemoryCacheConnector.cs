using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.InMemoryCache
{
    public interface IMemoryCacheConnector : IDisposable
    {
      //  string GetKey(string key);


        Task<string> GetKeyAsync(string key);
        Task<bool> SetKeyAsync(string key, string value);



        //Hash functions
        Task<bool> SetHashKeyAsync(string key, string hashKey, string value);
        Task<string> GetHashKeyAsync(string key, string hashKey);
        Task<KeyValuePair<string, string>[]> GetHashAllKeysAsync(string key);
    }
}
